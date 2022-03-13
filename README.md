An improved and adapted version of EpiILMCT:\\
1. fixed the transcov parameter of epictmcmc\\
2. new parameter real_gamma to replace the dysfunctional gamma parameter of epictmcmc. real_gamma=[prior type, initial, prior para1, prior para2, proposal variance], where 1 is gamma prior, 2 is half normal prior, 3 is uniform prior\\
3.datagen delta adapted to "known epidemic" mode: delta[1,1]= fixed incubation, delta[2,1]= fixed notification. Placeholder needed for delta[1,2], delta[2,2]\\
4.new parameter added to datagen: tmin, an optional parameter for customised starting time. tmin is effective only when bigger than the latest infection in initial cases\\ 
5. will add corrected example codes for ring cull/vaccination. 
6. will add example codes for Ripley's k function and DIC model selection
