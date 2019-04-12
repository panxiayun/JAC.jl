#
println("De) Test of the AutoIonization module with ASF from an internally generated initial- and final-state multiplet.")
#
JAC.define("print summary: open", "zzz-AutoIonization.sum")
JAC.define("method: continuum, asymptotic Coulomb")  ## JAC.define("method: continuum, Galerkin")
JAC.define("method: normalization, pure sine")       ## JAC.define("method: normalization, pure Coulomb")    JAC.define("method: normalization, pure sine")

wa = Atomic.Computation("xx",  Nuclear.Model(12.); grid=JAC.Radial.Grid("grid: by given parameters"; rnt = 2.0e-5, h = 5.0e-2, hp = 2.0e-2, NoPoints = 600), 
                        initialConfigs  =[Configuration("1s 2s^2 2p^6")],
                        finalConfigs    =[Configuration("1s^2 2s^2 2p^4"), Configuration("1s^2 2s 2p^5"), Configuration("1s^2 2p^6")], process = JAC.Auger,
                        processSettings = AutoIonization.Settings(true, true, true, Tuple{Int64,Int64}[(1,0)], 0., 1.0e6, 2, "Coulomb") )

wb = perform(wa)
JAC.define("print summary: close", "")


