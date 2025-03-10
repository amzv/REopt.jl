# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
const default_buildings = [
    "FastFoodRest",
    "FullServiceRest",
    "Hospital",
    "LargeHotel",
    "LargeOffice",
    "MediumOffice",
    "MidriseApartment",
    "Outpatient",
    "PrimarySchool",
    "RetailStore",
    "SecondarySchool",
    "SmallHotel",
    "SmallOffice",
    "StripMall",
    "Supermarket",
    "Warehouse",
    "FlatLoad",
    "FlatLoad_24_5",
    "FlatLoad_16_7",
    "FlatLoad_16_5",
    "FlatLoad_8_7",
    "FlatLoad_8_5"    
]


function find_ashrae_zone_city(lat, lon; get_zone=false)
    file_path = joinpath(@__DIR__, "..", "..", "data", "climate_cities.shp")
    shpfile = ArchGDAL.read(file_path)
	cities_layer = ArchGDAL.getlayer(shpfile, 0)

	# From https://yeesian.com/ArchGDAL.jl/latest/projections/#:~:text=transform%0A%20%20%20%20point%20%3D%20ArchGDAL.-,fromWKT,-(%22POINT%20(1120351.57%20741921.42
    # From https://en.wikipedia.org/wiki/Well-known_text_representation_of_geometry
	point = ArchGDAL.fromWKT(string("POINT (",lon," ",lat,")"))
	
	# No transformation needed
	archgdal_city = nothing
	for i in 1:ArchGDAL.nfeature(cities_layer)
		ArchGDAL.getfeature(cities_layer,i-1) do feature # 0 indexed
			if ArchGDAL.contains(ArchGDAL.getgeom(feature), point)
				archgdal_city = ArchGDAL.getfield(feature,"city")
			end
		end
	end
    if isnothing(archgdal_city)
        @warn "Could not find latitude/longitude in U.S. Using geometrically nearest city."
    elseif !get_zone
        return archgdal_city
    end
    cities = [
        (city="Miami", lat=25.761680, lon=-80.191790, zone="1A"),
        (city="Houston", lat=29.760427, lon=-95.369803, zone="2A"),
        (city="Phoenix", lat=33.448377, lon=-112.074037, zone="2B"),
        (city="Atlanta", lat=33.748995, lon=-84.387982, zone="3A"),
        (city="LasVegas", lat=36.1699, lon=-115.1398, zone="3B"),
        (city="LosAngeles", lat=34.052234, lon=-118.243685, zone="3B"),
        (city="SanFrancisco", lat=37.3382, lon=-121.8863, zone="3C"),
        (city="Baltimore", lat=39.290385, lon=-76.612189, zone="4A"),
        (city="Albuquerque", lat=35.085334, lon=-106.605553, zone="4B"),
        (city="Seattle", lat=47.606209, lon=-122.332071, zone="4C"),
        (city="Chicago", lat=41.878114, lon=-87.629798, zone="5A"),
        (city="Boulder", lat=40.014986, lon=-105.270546, zone="5B"),
        (city="Minneapolis", lat=44.977753, lon=-93.265011, zone="6A"),
        (city="Helena", lat=46.588371, lon=-112.024505, zone="6B"),
        (city="Duluth", lat=46.786672, lon=-92.100485, zone="7"),
        (city="Fairbanks", lat=59.0397, lon=-158.4575, zone="8"),
    ]
    min_distance = 0.0
    nearest_city = ""
    ashrae_zone = ""    
    for (i, c) in enumerate(cities)
        distance = sqrt((lat - c.lat)^2 + (lon - c.lon)^2)
        if i == 1
            min_distance = distance
            nearest_city = c.city
            ashrae_zone = c.zone
        elseif distance < min_distance
            min_distance = distance
            nearest_city = c.city
            ashrae_zone = c.zone
        end
    end
    
    # Optionally return both city and zone
    if get_zone
        if !isnothing(archgdal_city)
            nearest_city = archgdal_city
        end
        return nearest_city, ashrae_zone
    else
        return nearest_city
    end
end


"""
    built_in_load(type::String, city::String, buildingtype::String, 
        year::Int, annual_energy::Real, monthly_energies::AbstractArray{<:Real,1}
    )
Scale a normalized Commercial Reference Building according to inputs provided and return the 8760.
"""
function built_in_load(type::String, city::String, buildingtype::String, 
    year::Int, annual_energy::R, monthly_energies::AbstractArray{<:Real,1}
    ) where {R <: Real}

    @assert type in ["electric", "domestic_hot_water", "space_heating", "cooling"]
    monthly_scalers = ones(12)
    lib_path = joinpath(@__DIR__, "..", "..", "data", "load_profiles", type)

    profile_path = joinpath(lib_path, string("crb8760_norm_" * city * "_" * buildingtype * ".dat"))
    if occursin("FlatLoad", buildingtype)
        normalized_profile = custom_normalized_flatload(buildingtype, year)
    else 
        normalized_profile = vec(readdlm(profile_path, '\n', Float64, '\n'))
    end

    if length(monthly_energies) == 12
        annual_energy = 1.0  # do not scale based on annual_energy
        t0 = 1
        for month in 1:12
            plus_hours = daysinmonth(Date(string(year) * "-" * string(month))) * 24
            if month == 2 && isleapyear(year)
                plus_hours -= 24
            end
            month_total = sum(normalized_profile[t0:t0+plus_hours-1])
            if month_total == 0.0  # avoid division by zero
                monthly_scalers[month] = 0.0
            else
                monthly_scalers[month] = monthly_energies[month] / month_total
            end
            t0 += plus_hours
        end
    end

    scaled_load = Float64[]
    boiler_efficiency = 1.0
    used_kwh_per_mmbtu = 1.0  # do not convert electric loads
    if type in ["domestic_hot_water", "space_heating"]
        # CRB thermal "loads" are in terms of energy input required (boiler fuel), not the actual energy demand.
        # So we multiply the fuel energy by the boiler_efficiency to get the actual energy demand.
        boiler_efficiency = EXISTING_BOILER_EFFICIENCY
        used_kwh_per_mmbtu = KWH_PER_MMBTU  # do convert thermal loads
    end
    datetime = DateTime(year, 1, 1, 1)
    for ld in normalized_profile
        month = Month(datetime).value
        push!(scaled_load, ld * annual_energy * monthly_scalers[month] * boiler_efficiency * used_kwh_per_mmbtu)
        datetime += Dates.Hour(1)
    end

    return scaled_load
end


"""
    blend_and_scale_doe_profiles(
        constructor,
        latitude::Real,
        longitude::Real,
        year::Int,
        blended_doe_reference_names::Array{String, 1},
        blended_doe_reference_percents::Array{<:Real,1},
        city::String = "",
        annual_energy::Union{Real, Nothing} = nothing,
        monthly_energies::Array{<:Real,1} = Real[],
    )

Given `blended_doe_reference_names` and `blended_doe_reference_percents` use the `constructor` function to load in DoE 
    CRB profiles and create a single profile, where `constructor` is one of:
    - BuiltInElectricLoad
    - BuiltInDomesticHotWaterLoad
    - BuiltInSpaceHeatingLoad
    - BuiltInCoolingLoad
"""
function blend_and_scale_doe_profiles(
    constructor,
    latitude::Real,
    longitude::Real,
    year::Int,
    blended_doe_reference_names::Array{String, 1},
    blended_doe_reference_percents::Array{<:Real,1},
    city::String = "",
    annual_energy::Union{Real, Nothing} = nothing,
    monthly_energies::Array{<:Real,1} = Real[],
    addressable_load_fraction::Union{<:Real, AbstractVector{<:Real}} = 1.0
    )

    @assert sum(blended_doe_reference_percents) ≈ 1 "The sum of the blended_doe_reference_percents must equal 1"
    if year != 2017
        @debug "Changing ElectricLoad.year to 2017 because DOE reference profiles start on a Sunday."
    end
    year = 2017
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)  # avoid redundant look-ups
    end
    profiles = Array[]  # collect the built in profiles
    if constructor in [BuiltInSpaceHeatingLoad, BuiltInDomesticHotWaterLoad]
        for name in blended_doe_reference_names
            push!(profiles, constructor(city, name, latitude, longitude, year, addressable_load_fraction, annual_energy, monthly_energies))
        end
    else
        for name in blended_doe_reference_names
            push!(profiles, constructor(city, name, latitude, longitude, year, annual_energy, monthly_energies))
        end
    end
    if isnothing(annual_energy) # then annual_energy should be the sum of all the profiles' annual kwhs
        # we have to rescale the built in profiles to the total_kwh by normalizing them with their
        # own annual kwh and multiplying by the total kwh
        annual_kwhs = [sum(profile) for profile in profiles]
        total_kwh = sum(annual_kwhs)
        monthly_scaler = 1
        if length(monthly_energies) == 12
            monthly_scaler = length(blended_doe_reference_names)
        end
        for idx in 1:length(profiles)
            profiles[idx] .*= total_kwh / annual_kwhs[idx] / monthly_scaler
        end
    end
    for idx in 1:length(profiles)  # scale the profiles
        profiles[idx] .*= blended_doe_reference_percents[idx]
    end
    sum(profiles)
end

function custom_normalized_flatload(doe_reference_name, year)
    # built in profiles are assumed to be hourly
    periods = 8760
    # get datetimes of all hours 
    if Dates.isleapyear(year)
        end_year_datetime = DateTime(string(year)*"-12-30T23:00:00")
    else
        end_year_datetime = DateTime(string(year)*"-12-31T23:00:00")
    end
    dt_hourly = collect(DateTime(string(year)*"-01-01T00:00:00"):Hour(1):end_year_datetime)

    # create boolean masks for weekday and hour of day filters
    weekday_mask = convert(Vector{Int}, ones(periods))
    hour_mask = convert(Vector{Int}, ones(periods))
    weekends = [6,7]
    hour_range_16 = 6:21  # DateTime hours are 0-indexed, so this is 6am (7th hour of the day) to 10pm (end of 21st hour)
    hour_range_8 = 9:16  # This is 9am (10th hour of the day) to 5pm (end of 16th hour)
    if !(doe_reference_name == "FlatLoad")
        for (i,dt) in enumerate(dt_hourly)
            # Zero out no-weekend operation
            if doe_reference_name in ["FlatLoad_24_5","FlatLoad_16_5","FlatLoad_8_5"]
                if Dates.dayofweek(dt) in weekends
                    weekday_mask[i] = 0
                end
            end
            # Assign 1's for 16 or 8 hour shift profiles
            if doe_reference_name in ["FlatLoad_16_5","FlatLoad_16_7"]
                if !(Dates.hour(dt) in hour_range_16)
                    hour_mask[i] = 0
                end
            elseif doe_reference_name in ["FlatLoad_8_5","FlatLoad_8_7"]
                if !(Dates.hour(dt) in hour_range_8)
                    hour_mask[i] = 0
                end
            end
        end
    end
    # combine masks to a dt_hourly where 1 is on and 0 is off
    dt_hourly_binary = weekday_mask .* hour_mask
    # convert combined masks to a normalized profile
    sum_dt_hourly_binary = sum(dt_hourly_binary)
    normalized_profile = [i/sum_dt_hourly_binary for i in dt_hourly_binary]
    return normalized_profile
end

"""
    get_monthly_energy(power_profile::AbstractArray{<:Real,1};
                        year::Int64=2017)

Get monthly energy from an hourly load profile.
"""
function get_monthly_energy(power_profile::AbstractArray{<:Real,1}; 
                            year::Int64=2017)
    t0 = 1
    monthly_energy_total = zeros(12)
    for month in 1:12
        plus_hours = daysinmonth(Date(string(year) * "-" * string(month))) * 24
        if month == 2 && isleapyear(year)
            plus_hours -= 24
        end
        if !isempty(power_profile)
            monthly_energy_total[month] = sum(power_profile[t0:t0+plus_hours-1])
        else
            throw(@error("Must provide power_profile"))
        end
        t0 += plus_hours
    end

    return monthly_energy_total
end
