using Test
using JuMP
using HiGHS
using JSON
using REopt

for i in 1:1000
    post_name = "case_$i.json" 
    #post_name = "pv_storage.json" 
    post = JSON.parsefile("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/Doe/Scenarios/$post_name")
    model = Model(HiGHS.Optimizer)
    results = run_reopt(model, post)
    #storage = JSON.json(results["ElectricStorage"])
    #utility = JSON.json(results["ElectricUtility"])
    #tariff = JSON.json(results["ElectricTariff"])
    #financial = JSON.json(results["Financial"])
    resdata = JSON.json(results)


    # write the file with the stringdata variable information
    #open("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/scenarios/results/storageresults$i.json", "w") do f
    #        write(f, storage)
    # end
    # open("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/scenarios/results/utilityresults$i.json", "w") do f
    #    write(f, utility)
    #end
    #open("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/scenarios/results/tariffresults$i.json", "w") do f
    #    write(f, tariff)
    #end
    #open("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/scenarios/results/financialresults$i.json", "w") do f
    #    write(f, financial)
    #end
    open("c://Users/amzv3/Documents/Github/REopt.jl/test/gc-test/Doe/run_loads_$i.json", "w") do f
        write(f, resdata)
    end
     
end





