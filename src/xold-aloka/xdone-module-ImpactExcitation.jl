
"""
`module  JAC.ImpactExcitation`  
    ... a submodel of JAC that contains all methods for computing electron impact excitation cross sections and collision strengths.
"""
module ImpactExcitation 

    #SF: Please, keep external and internal modules separate from each other 
    using Printf, Distributed, SpecialFunctions,
          ..AngularMomentum, ..Basics, ..Continuum, ..Defaults, ..InteractionStrength, ..ManyElectron, 
                  ..Nuclear, ..Radial, ..SpinAngular, ..TableStrings, ..RadialIntegrals, ..Radial,
    #SF: delete              Distributed, SpecialFunctions
                  
    #==
    """
    `struct  ImpactExcitationSettings  <:  AbstractProcessSettings`  ... defines a type for the details and parameters of computing electron-impact excitation lines.

        + electronEnergies         ::Array{Float64,1}             ... List of impact-energies of the incoming elecgtrons (in user-defined units).
        + calcEffCollisionStrength ::Bool                         ... True, if effective collision strength need to be calculated, and false otherwise.
        + calcRateCoefficient      ::Bool                         ... True, if the plasma rate coefficients to be calculated, and false otherwise.
        + printBefore              ::Bool                         ... True, if all energies and lines are printed before their evaluation.
        + lineSelection            ::LineSelection                ... Specifies the selected levels, if any.
        + energyShift              ::Float64                      ... An overall energy shift for all transitions |i> --> |f>.
        + maxKappa                 ::Int64                        ... Maximum kappa value of partial waves to be included.
        + operator                 ::AbstractEeInteraction   
            ... Interaction operator that is to be used for evaluating the e-e interaction amplitudes; allowed values are: 
                CoulombInteraction(), BreitInteraction(), ...
    """
    struct Settings  <:  AbstractProcessSettings
        electronEnergies          ::Array{Float64,1}
        calcEffCollisionStrength  ::Bool
        calcRateCoefficient       ::Bool 
        printBefore               ::Bool 
        lineSelection             ::LineSelection  
        energyShift               ::Float64    
        maxKappa                  ::Int64
        operator                  ::AbstractEeInteraction 
    end 


    """
    `ImpactExcitation.Settings()`  ... constructor for the default values of electron-impact excitation line computations.
    """
    function Settings()
       Settings( Float64[], false, false, false, LineSelection(), 0., 0, CoulombInteraction())
    end


    # `Base.show(io::IO, settings::ImpactExcitation.Settings)`  ... prepares a proper printout of the variable settings::ImpactExcitation.Settings.
    function Base.show(io::IO, settings::ImpactExcitation.Settings) 
        println(io, "electronEnergies:           $(settings.electronEnergies)  ")
        println(io, "calcRateCoefficient:        $(settings.calcRateCoefficient)  ")
        println(io, "calcEffCollisionStrength:   $(settings.calcEffCollisionStrength)  ")
        println(io, "printBefore:                $(settings.printBefore)  ")
        println(io, "lineSelection:              $(settings.lineSelection)  ")
        println(io, "energyShift:                $(settings.energyShift)  ")
        println(io, "maxKappa:                   $(settings.maxKappa)  ")
        println(io, "operator:                   $(settings.operator)  ")
    end
    ==#
    

    #SF: In the doc-strings, please, use "full" names ... to easily recognize with ? where structs and procedures are located
    #SF: Please, keep length of lines shorter than 140 ... better < 130 (usually)
    """
    `struct ImpactExcitation.RateSettings`          
        ... Defines a type for the details for calculating the excitation rate coefficients or effective collision strengths
        
        + maxElectronEnergy       ::Int64              ... Maximum energy of initial electron ( maxElectronEnergy * Excitation threshold)
        + NoFreeElectronEnergy    ::Int64              ... Number of electron energies at which cross sections are calculated
        + temperatures            ::Array{Float64, 1}  ... Electron temperatures [K] for the rate coefficients or effective collision strengths
    """
    struct RateSettings
        maxElectronEnergy       ::Int64
        NoFreeElectronEnergy    ::Int64
        temperatures            ::Array{Float64, 1}
    end


    """
    `ImpactExcitation.RateSettings()`  ... constructor for the default values of electron-impact excitation line computations.
    """
    function RateSettings()
       RateSettings( 50, 6, [5e4, 1e5, 2e5, 3e5, 5e5, 7e5, 1e6])
    end


    """
    `struct  RateCoefficients`      ... Defines a type for the output results from excitation rate or efective collision strengths calculations
        + initialLevel        ::Level               ... Initial level, from the level excitation to be considered
        + finalLevel          ::Level               ... Final level,  to the level excitation to be considered
        + temperatures        ::Array{Float64,1}    ... Temperatures in [K] to calcualte excitaiton rates or effective collision strengths
        + alphas              ::Array{Float64,1}    ... Excitation rate coefficients in [cm^3/s] corresponding to the temperatures
        + effOmegas           ::Array{Float64,1}    ... Effective collsion strengths
    """
    struct  RateCoefficients   
        initialLevel        ::Level 
        finalLevel          ::Level 
        temperatures        ::Array{Float64,1}
        alphas             ::Array{Float64,1}
        effOmegas           ::Array{Float64,1}
    end
    #SF: Perhaps, better effectiveStrength  ... because "strength" if used a various places.


    """
    `ImpactExcitation.RateCoefficients()`  ... constructor for the default values of electron-impact excitation rate coefficient or
                                                effective collision strength computations.
    """
    function RateCoefficients()
        RateCoefficients(Level(), Level(), Float64[], Float64[], Float64[])
    end


    # `Base.show(io::IO, rateSettings::ImpactExcitation.RateSettings)`  ... prepares a proper printout of the variable settings::ImpactExcitation.RateSettings
    function Base.show(io::IO, rateSettings::ImpactExcitation.RateSettings) 
        println(io, "maxElectronEnergy:           $(rateSettings.maxElectronEnergy)  ")
        println(io, "NoFreeElectronEnergy:        $(rateSettings.NoFreeElectronEnergy)  ")
        println(io, "temperatures:                $(rateSettings.temperatures)  ")
    end

    
    #SF: 
    """
    `struct  ImpactExcitationSettings  <:  AbstractProcessSettings`  ... defines a type for the details and parameters of computing electron-impact excitation lines.

        + lineSelection            ::LineSelection                ... Specifies the selected levels, if any.
        + electronEnergies         ::Array{Float64,1}             ... List of impact-energies of the incoming elecgtrons (in user-defined units).
        + energyShift              ::Float64                      ... An overall energy shift for all transitions |i> --> |f>.
        + maxKappa                 ::Int64                        ... Maximum kappa value of partial waves to be included.
        + calcRateCoefficient      ::Bool                         ... True, if the plasma rate coefficients to be calculated, and false otherwise.
        + calcEffCollisionStrength ::Bool                         ... True, if effective collision strength need to be calculated, and false otherwise.
        + rateSettings             ::RateSettings                 ... Inputs for excitation rate or effective collision strength calculations
        + printBefore              ::Bool                         ... True, if all energies and lines are printed before their evaluation.
        + operator                 ::AbstractEeInteraction   
            ... Interaction operator that is to be used for evaluating the e-e interaction amplitudes; allowed values are: 
                CoulombInteraction(), BreitInteraction(), ...
    """
    struct Settings  <:  AbstractProcessSettings
        lineSelection             ::LineSelection  
        electronEnergies          ::Array{Float64,1}
        energyShift               ::Float64   
        maxKappa                  ::Int64
        calcRateCoefficient       ::Bool 
        calcEffCollisionStrength  ::Bool
        rateSettings              ::RateSettings
        printBefore               ::Bool  
        operator                  ::AbstractEeInteraction 
    end 


    """
    `ImpactExcitation.Settings()`  ... constructor for the default values of electron-impact excitation line computations.
    """
    function Settings()
       Settings( LineSelection(), Float64[], 0., 400, false, false, RateSettings(), false, CoulombInteraction())
    end


    #SF: For these 'settings-procedures', I often shown only lineSelection = ...,   electronEnergies = ...,
    #SF: in order to keep the printout for ? ImpactExcitation.Settings simpler; please, have a short look in other modules.
    """
    `ImpactExcitation.Settings(set::ImpactExcitation.Settings;
        lineSelection::Union{Nothing, LineSelection} = nothing, 
        electronEnergies::Union{ Nothing, Array{Float64,1} } = nothing,
        energyShift::Union{Nothing, Float64} = nothing,
        maxKappa::Union{Nothing, Int64} = nothing,
        calcRateCoefficient::Union{Nothing, Bool} = nothing,
        calcEffCollisionStrength::Union{Nothing, Bool} = nothing,
        rateSettings::Union{Nothing, RateSettings} = nothing,
        printBefore::Union{Nothing, Bool} = nothing,
        operator::Union{Nothing, AbstractEeInteraction} = nothing )`

        ... constructor for modifying the given ImpactExcitation.Settings by 'overwriting' the previously selected parameters.

    """
    function Settings(set::ImpactExcitation.Settings;
        lineSelection::Union{Nothing, LineSelection} = nothing, 
        electronEnergies::Union{ Nothing, Array{Float64,1} } = nothing,
        energyShift::Union{Nothing, Float64} = nothing,
        maxKappa::Union{Nothing, Int64} = nothing,
        calcRateCoefficient::Union{Nothing, Bool} = nothing,
        calcEffCollisionStrength::Union{Nothing, Bool} = nothing,
        rateSettings::Union{Nothing, RateSettings} = nothing,
        printBefore::Union{Nothing, Bool} = nothing,
        operator::Union{Nothing, AbstractEeInteraction} = nothing )

        if lineSelection == nothing     lineSelectionx = set.lineSelection       else lineSelectionx = lineSelection        end
        if electronEnergies == nothing  electronEnergiesx = set.electronEnergies else electronEnergiesx = electronEnergies  end
        if energyShift == nothing       energyShiftx = set.energyShift           else energyShiftx = energyShift            end
        if maxKappa == nothing          maxKappax = set.maxKappa                 else maxKappax = maxKappa                  end
        if calcRateCoefficient == nothing   calcRateCoefficientx = set.calcRateCoefficient else calcRateCoefficientx = calcRateCoefficient end
        if calcEffCollisionStrength == nothing  calcEffCollisionStrengthx = set.calcEffCollisionStrength else calcEffCollisionStrengthx = calcEffCollisionStrength end
        if rateSettings == nothing      rateSettingsx = set.rateSettings         else rateSettingsx = rateSettings          end
        if printBefore == nothing       printBeforex = set.printBefore           else printBeforex = printBefore            end
        if operator == nothing          operatorx = set.operator                 else operatorx = operator                  end

        Settings( lineSelectionx, electronEnergiesx, energyShiftx, maxKappax, calcRateCoefficientx, calcEffCollisionStrengthx, 
                 rateSettingsx, printBeforex, operatorx )

    end


    # `Base.show(io::IO, settings::ImpactExcitation.Settings)`  ... prepares a proper printout of the variable settings::ImpactExcitation.Settings.
    function Base.show(io::IO, settings::ImpactExcitation.Settings) 
        println(io, "lineSelection:              $(settings.lineSelection)  ")
        println(io, "electronEnergies:           $(settings.electronEnergies)  ")
        println(io, "energyShift:                $(settings.energyShift)  ")
        println(io, "maxKappa:                   $(settings.maxKappa)  ")
        println(io, "calcRateCoefficient:        $(settings.calcRateCoefficient)  ")
        println(io, "calcEffCollisionStrength:   $(settings.calcEffCollisionStrength)  ")
        println(io, "rateSettings:               $(settings.rateSettings)  ")
        println(io, "printBefore:                $(settings.printBefore)  ")
        println(io, "operator:                   $(settings.operator)  ")
    end


    """
    `struct  ImpactExcitation.Channel`  
        ... defines a type for a electron-impact excitaiton channel to help characterize the incoming and outgoing (continuum) states of 
            many electron-states with a single free electron

        + initialKappa     ::Int64              ... partial-wave of the incoming free electron
        + finalKappa       ::Int64              ... partial-wave of the outgoing free electron
        + symmetry         ::LevelSymmetry      ... total angular momentum and parity of the scattering state
        + initialPhase     ::Float64            ... phase of the incoming partial wave
        + finalPhase       ::Float64            ... phase of the outgoing partial wave
        + amplitude        ::Complex{Float64}   ... Collision amplitude associated with the given channel.
    """
    struct  Channel
        initialKappa       ::Int64 
        finalKappa         ::Int64 
        symmetry           ::LevelSymmetry
        initialPhase       ::Float64
        finalPhase         ::Float64
        amplitude          ::Complex{Float64}
    end


    # `Base.show(io::IO, channel::ImpactExcitation.Channel)`  ... prepares a proper printout of the variable channel::ImpactExcitation.Channel.
    function Base.show(io::IO, channel::ImpactExcitation.Channel) 
        println(io, "initialKappa:       $(channel.initialKappa)  ")
        println(io, "finalKappa:         $(channel.finalKappa)  ")
        println(io, "symmetry:           $(channel.symmetry)  ")
        println(io, "initialPhase:       $(channel.initialPhase)  ")
        println(io, "finalPhase:         $(channel.finalPhase)  ")
        println(io, "amplitude:          $(channel.amplitude)  ")
    end


    """
    `struct  ImpactExcitation.Line`  
        ... defines a type for a electron-impact excitation line that may include the definition of channels and their corresponding amplitudes.

        + initialLevel           ::Level         ... initial- (bound-state) level
        + finalLevel             ::Level         ... final- (bound-state) level
        + initialElectronEnergy  ::Float64       ... energy of the incoming (initial-state) free-electron
        + finalElectronEnergy    ::Float64       ... energy of the outgoing (final-state) free-electron
        + crossSection           ::Float64       ... total cross section of this line
        + collisionStrength      ::Float64       ... total collision strength of this line
        + weight                   ::Float64 
        + channels               ::Array{ImpactExcitation.Channel,1}  ... List of ImpactExcitation channels of this line.
        + convergence            ::Float64       ... convergence of calculation
    """
    struct  Line
        initialLevel             ::Level
        finalLevel               ::Level
        initialElectronEnergy    ::Float64
        finalElectronEnergy      ::Float64
        crossSection             ::Float64 
        collisionStrength        ::Float64 
        weight                   ::Float64 
        channels                 ::Array{ImpactExcitation.Channel,1}
        convergence              ::Float64
    end 


    """
    `ImpactExcitation.Line()`  ... 'empty' constructor for an electron-impact excitation line between a specified initial and final level.
    """
    function Line()
        Line(Level(), Level(), 0., 0., 0., 0., 0., ImpactExcitation.Channel[], 1.0 )
    end


    """
    `ImpactExcitation.Line(initialLevel::Level, finalLevel::Level, crossSection::Float64)`  
        ... constructor for an electron-impact excitation line between a specified initial and final level.
    """
    function Line(initialLevel::Level, finalLevel::Level, crossSection::Float64)
        Line(initialLevel, finalLevel, 0., 0., crossSection, 0., 0., ImpactExcitation.Channel[], 1.0 )
    end


    # `Base.show(io::IO, line::ImpactExcitation.Line)`  ... prepares a proper printout of the variable line::ImpactExcitation.Line.
    function Base.show(io::IO, line::ImpactExcitation.Line) 
        println(io, "initialLevel:            $(line.initialLevel)  ")
        println(io, "finalLevel:              $(line.finalLevel)  ")
        println(io, "initialElectronEnergy:   $(line.initialElectronEnergy)  ")
        println(io, "finalElectronEnergy:     $(line.finalElectronEnergy)  ")
        println(io, "crossSection:            $(line.crossSection)  ")
        println(io, "collisionStrength:       $(line.collisionStrength)  ")
        println(io, "weight:                  $(line.weight)  ")
        println(io, "channels:                $(line.channels)  ")
    end


    """
    `ImpactExcitation.amplitude(kind::AbstractEeInteraction, channel::ImpactExcitation.Channel, cFinalLevel::Level, cInitialLevel::Level, 
                                grid::Radial.Grid; printout::Bool=true)`  
        ... to compute the kind in  CoulombInteraction(), BreitInteraction(), CoulombBreit() electron-impact interaction amplitude 
            <(alpha_f J_f, kappa_f) J_t || O^(e-e, kind) || (alpha_i J_i, kappa_i) J_t>  due to the interelectronic interaction for 
            the given final and initial (continuum) level. A value::ComplexF64 is returned.
    """
    function amplitude(kind::AbstractEeInteraction, channel::ImpactExcitation.Channel, cFinalLevel::Level, cInitialLevel::Level, 
                       grid::Radial.Grid; printout::Bool=true)
        nf = length(cFinalLevel.basis.csfs);      fPartial = Subshell(9,channel.finalKappa)         
        ni = length(cInitialLevel.basis.csfs);    iPartial = Subshell(9,channel.initialKappa)    
        
        if  printout  printstyled("Compute ($kind) e-e matrix of dimension $nf x $ni in the final- and initial-state (continuum) bases " *
                                  "for the transition [$(cInitialLevel.index)- ...] " * 
                                  "and for partial waves $(string(fPartial)[2:end]),  $(string(iPartial)[2:end])... ", color=:light_green)    end
        matrix = zeros(Float64, nf, ni)
        #
        ##x @show cInitialLevel.basis.subshells
        ##x @show cFinalLevel.basis.subshells
        if  cInitialLevel.basis.subshells == cFinalLevel.basis.subshells
            iLevel = cInitialLevel;   fLevel = cFinalLevel
        else
            subshells = Basics.merge(cInitialLevel.basis.subshells, cFinalLevel.basis.subshells)
            iLevel    = Level(cInitialLevel, subshells)
            fLevel    = Level(cFinalLevel,   subshells)
        end
        #
        if      kind in [ CoulombInteraction(), BreitInteraction(), CoulombBreit()]        ## pure V^Coulomb interaction
        #--------------------------------------------------------------------------
            for  r = 1:nf
                for  s = 1:ni
                    #if ( fLevel.mc[r] == 0.0 && iLevel.mc[s] == 0.0 ) continue end
                    if  iLevel.basis.csfs[s].J != iLevel.J  ||  iLevel.basis.csfs[s].parity != iLevel.parity      continue    end 
                    subshellList = fLevel.basis.subshells
                    op2  = SpinAngular.TwoParticleOperator(0, plus, true)
                    wa   = SpinAngular.computeCoefficients(op2, fLevel.basis.csfs[r], iLevel.basis.csfs[s], subshellList)
                    #
                    me = 0.

                    for  coeff in wa
                        # Comment below to include exchange in account
                        if ( (coeff.c.n == 101) && (coeff.nu > 40) )  continue end

                        if   kind in [ CoulombInteraction(), CoulombBreit()]    
                            me = me + coeff.V * InteractionStrength.XL_Coulomb(coeff.nu, 
                                                    fLevel.basis.orbitals[coeff.a], fLevel.basis.orbitals[coeff.b],
                                                    iLevel.basis.orbitals[coeff.c], iLevel.basis.orbitals[coeff.d], grid)   end
                        if   kind in [ BreitInteraction(), CoulombBreit()]    
                            me = me + coeff.V * InteractionStrength.XL_Breit(coeff.nu, 
                                                    fLevel.basis.orbitals[coeff.a], fLevel.basis.orbitals[coeff.b],
                                                    iLevel.basis.orbitals[coeff.c], iLevel.basis.orbitals[coeff.d], grid)   end
                    end
                    matrix[r,s] = me
                end
            end 
            if  printout  printstyled("done. \n", color=:light_green)    end
            amplitude = transpose(fLevel.mc) * matrix * iLevel.mc 
            amplitude = im^( -1.0 * Basics.subshell_l(Subshell(102, channel.finalKappa)) )   * exp(  im*channel.finalPhase )   * 
                        im^Basics.subshell_l(Subshell(101, channel.initialKappa)) * exp(  im*channel.initialPhase ) * amplitude
            @show amplitude
            #
            #
         elseif  kind == "H-E"
        #--------------------
            amplitude = 0.;    error("stop a")
        else    error("stop b")
        end
        
        return( amplitude )
    end


    #SF: For my taste, the "widths (< about 130)" becomes a too wide ... and leads to unintended line-breaks in my editor.
    """
    `ImpactExcitation.computeAmplitudesProperties(line::ImpactExcitation.Line, nm::Nuclear.Model, grid::Radial.Grid, 
                                                  settings::ImpactExcitation.Settings; printout::Bool=true)`  
        ... to compute all amplitudes and properties of the given line; a line::ImpactExcitation.Line is returned for which the amplitudes and
            properties are now evaluated.
    """
    function  computeAmplitudesProperties(line::ImpactExcitation.Line, nm::Nuclear.Model, grid::Radial.Grid, 
                                          settings::ImpactExcitation.Settings; printout::Bool=true)
        newChannels = ImpactExcitation.Channel[];   
        contSettings = Continuum.Settings(false, grid.NoPoints-5);   cross = 0.;   coll = 0.; convergence = 1.
        conv = 0.; conv0 = 0. ; n = 0
        
        # Define a common subshell list for both multiplets
        subshellList = Basics.generate("subshells: ordered list for two bases", line.finalLevel.basis, line.initialLevel.basis)
        Defaults.setDefaults("relativistic subshell list", subshellList; printout=false)
        
        # First determine a common set of continuum orbitals for the incoming and outgoing electron
        ciOrbitals = Dict{Subshell, Orbital}();     ciPhases = Dict{Subshell, Float64}()
        cfOrbitals = Dict{Subshell, Orbital}();     cfPhases = Dict{Subshell, Float64}()
        #
        symi = LevelSymmetry(line.initialLevel.J, line.initialLevel.parity);    symf = LevelSymmetry(line.finalLevel.J, line.finalLevel.parity) 
        #
        kappa = 1
        while kappa <= settings.maxKappa
            for  inKappa = -kappa:kappa
                if  inKappa == 0    continue    end
                insymtList = AngularMomentum.allowedTotalSymmetries(symi, inKappa)
                for  outKappa = -(kappa):kappa
                    if  outKappa == 0  || ( abs(inKappa) < kappa && abs(outKappa) < kappa )  continue    end
                    outsymtList = AngularMomentum.allowedTotalSymmetries(symf, outKappa)
                    for  symt in insymtList
                        if symt in outsymtList
                            channel = ImpactExcitation.Channel( inKappa, outKappa, symt, 0., 0.,Complex(0.))
                            # Generate the continuum orbitals if they were not yet generated before
                            iSubshell  = Subshell(101, channel.initialKappa)
                            if  !haskey(ciOrbitals, iSubshell) 
                                newiLevel  = Basics.generateLevelWithSymmetryReducedBasis(line.initialLevel, subshellList)
                                ciOrbital, iPhase     = Continuum.generateOrbitalForLevel(line.initialElectronEnergy, iSubshell, newiLevel, nm, grid, contSettings)
                                ciOrbitals[iSubshell] = ciOrbital;      ciPhases[iSubshell] = iPhase
                                println("\n Initial channel")
                            end
                            
                            fSubshell  = Subshell(102, channel.finalKappa)
                            if  !haskey(cfOrbitals, fSubshell)
                                newfLevel  = Basics.generateLevelWithSymmetryReducedBasis(line.finalLevel,   subshellList)
                                cfOrbital, fPhase     = Continuum.generateOrbitalForLevel(line.finalElectronEnergy,   fSubshell, newfLevel, nm, grid, contSettings)
                                cfOrbitals[fSubshell] = cfOrbital;      cfPhases[fSubshell] = fPhase
                                println("\n Final channel")
                            end
                        #end
                        
                        #for channel in line.channels
                            # Generate two continuum orbitals
                            newiLevel  = Basics.generateLevelWithSymmetryReducedBasis(line.initialLevel, subshellList)
                            newfLevel  = Basics.generateLevelWithSymmetryReducedBasis(line.finalLevel,   subshellList)
                            iSubshell  = Subshell(101, channel.initialKappa)
                            fSubshell  = Subshell(102, channel.finalKappa)
                            ciOrbital  = ciOrbitals[iSubshell];     iPhase = ciPhases[iSubshell]
                            cfOrbital  = cfOrbitals[fSubshell];     fPhase = cfPhases[fSubshell]
                            newiLevel = Basics.generateLevelWithExtraElectron(ciOrbital, channel.symmetry, newiLevel)
                            newiLevel = Basics.generateLevelWithExtraSubshell(fSubshell,   newiLevel)
                            newfLevel = Basics.generateLevelWithExtraSubshell(iSubshell, newfLevel)
                            newfLevel = Basics.generateLevelWithExtraElectron(cfOrbital, channel.symmetry, newfLevel)
                            newChannel = ImpactExcitation.Channel(channel.initialKappa, channel.finalKappa, channel.symmetry, iPhase, fPhase, 0.)
                            #
                            amplitude  = ImpactExcitation.amplitude(settings.operator, newChannel, newfLevel, newiLevel, grid, printout=printout)

                            coll       = coll + AngularMomentum.bracket([channel.symmetry.J]) * ( conj(amplitude) * amplitude ).re

                            #SF: I avoided so far this += assignment ... but leave this to you
                            conv += (conj(amplitude) * amplitude).re

                            push!( newChannels, ImpactExcitation.Channel(newChannel.initialKappa, newChannel.finalKappa, newChannel.symmetry, iPhase, fPhase, amplitude) )
                        end
                    end
                end
            end
            
            # Checking convergence
            convergence = abs(conv - conv0)/conv
            if convergence < 1e-5 
                printstyled("\nConvergence Achieved "; bold=true, underline=true, color=:light_red); 
                if n == 5 
                    printstyled("\nConvergence Achieved "; bold=true, underline=true, color=:light_red); break
                end
                n += 1
            end
            conv0 = conv
            kappa += 1
        end

        wc = Defaults.getDefaults("speed of light: c")

        qa = sqrt( (line.initialElectronEnergy/wc)^2 + 2*line.initialElectronEnergy )
        qb = sqrt( (line.finalElectronEnergy/wc)^2 + 2*line.finalElectronEnergy )

        initialEnergy = sqrt( (qa*wc)^2 + wc^4 );    finalEnergy = sqrt( (qb*wc)^2 + wc^4 )

        N = 4. * sqrt( (initialEnergy + wc^2) * ( finalEnergy + wc^2 ) / ( initialEnergy * finalEnergy ) ) / qa / qb
        #N = N / sqrt( qa / pi / line.initialElectronEnergy) / sqrt( qb / pi / line.finalElectronEnergy)

        coll = coll * N 
        cross = coll * pi / ( (qa^2) * (Basics.twice(line.initialLevel.J) + 1) )

        newLine = ImpactExcitation.Line( line.initialLevel, line.finalLevel, line.initialElectronEnergy, line.finalElectronEnergy,
                                         cross, coll, line.weight, newChannels, convergence )
        displayLineResult(newLine)
        return( newLine )
    end


    """
    `ImpactExcitation.computeLines(finalMultiplet::Multiplet, initialMultiplet::Multiplet, nm::Nuclear.Model, grid::Radial.Grid, 
                                   settings::ImpactExcitation.Settings; output=true)`  
        ... to compute the electron-impact excitation transition amplitudes and all properties as requested by the given settings. 
            A list of lines::Array{ImpactExcitation.Lines} is returned.
    """
    function  computeLines(finalMultiplet::Multiplet, initialMultiplet::Multiplet, nm::Nuclear.Model, grid::Radial.Grid, settings::ImpactExcitation.Settings; 
                           output=true)
        println("")
        #SF: These are two lines where I would accept "wide code lines"  ... it is simply much easier to read in this way.
        printstyled("ImpactExcitation.computePathways(): The computation of electron-impact excitation cross sections starts now ... \n", color=:light_green)
        printstyled("--------------------------------------------------------------------------------------------------------------- \n", color=:light_green)
        println("")
        #
        lines = ImpactExcitation.determineLines(finalMultiplet, initialMultiplet, settings)
        # Display all selected lines before the computations start
        if  settings.printBefore    ImpactExcitation.displayLines(lines)    end
        # Calculate all amplitudes and requested properties
        if nprocs() > 1
            newLines = pmap(line -> ImpactExcitation.computeAmplitudesProperties(line, nm, grid, settings), lines)
        else
            newLines = lines
            Threads.@threads for l in eachindex(lines)
                newLines[l] = ImpactExcitation.computeAmplitudesProperties(lines[l], nm, grid, settings)
            end
        end
        # Print all results to screen
        ImpactExcitation.displayResults(newLines)
        
        if settings.calcRateCoefficient 
            rates     = computeRateCoefficients(newLines, settings.rateSettings)
            ImpactExcitation.displayResults(rates)
        elseif settings.calcEffCollisionStrength
            effOmegas = computeEffCollisionStrength(newLines, settings.rateSettings)
            ImpactExcitation.displayResults(effOmegas)
        end
        #
        if    output    return( newLines );
        else            return( nothing );
        end
    end


    """
    `ImpactExcitation.computeMatrix(finalBasis::Basis, initialBasis::Basis, settings::ImpactExcitation.Settings)`  
        ... to compute the transition matrix  (<finalContinuumCSF_r|| V(e-e) ||initialContinuumCSF_s>)  between the CSF_r from the 
            finalContinuumBasis and the CSF_s from the initialContinuumBasis. A (non-quadratic) matrix::Array{Float64,2} with 
            dimensions [length(finalContinuumBasis.csfs) x length(initialContinuumBasis.csfs)] is returned. Note that this transition 
            matrix is typically specific to just one Eimex channel due to the different energies, partial waves and overall symmetry 
            of the scattering states. **Not yet implemented !**
    """
    function computeMatrix(finalBasis::Basis, initialBasis::Basis, settings::ImpactExcitation.Settings)   
        error("Not yet implemented.")
    end



    """
    `ImpactExcitation.determineChannels(finalLevel::Level, initialLevel::Level, settings::ImpactExcitation.Settings)`  
        ... to determine a list of electron-impact excitation Channels for a transitions from the initial to the final level and by 
            taking into account the particular settings of for this computation; an Array{ImpactExcitation.Channel,1} is returned.
    """
    function determineChannels(finalLevel::Level, initialLevel::Level, settings::ImpactExcitation.Settings)
        channels = ImpactExcitation.Channel[];   
        symi = LevelSymmetry(initialLevel.J, initialLevel.parity);    symf = LevelSymmetry(finalLevel.J, finalLevel.parity) 
        #
        for  inKappa = -settings.maxKappa:settings.maxKappa
            if  inKappa == 0    continue    end
            symtList = AngularMomentum.allowedTotalSymmetries(symi, inKappa)
            for  symt in symtList
                outKappaList = AngularMomentum.allowedKappaSymmetries(symt, symf)
                for  outKappa in outKappaList
                    push!(channels, ImpactExcitation.Channel( inKappa, outKappa, symt, 0., 0.,Complex(0.)) )
                end
            end
        end
        return( channels )  
    end


    """
    `ImpactExcitation.determineLines(finalMultiplet::Multiplet, initialMultiplet::Multiplet, settings::ImpactExcitation.Settings)`  
        ... to determine a list of ImpactExcitation.Line's for transitions between levels from the initial- and final-state multiplets, 
            and by taking into account the particular selections and settings for this computation; an Array{ImpactExcitation.Line,1} is 
            returned. Apart from the level specification, all physical properties are set to zero during the initialization process.
    """
    function  determineLines(finalMultiplet::Multiplet, initialMultiplet::Multiplet, settings::ImpactExcitation.Settings)
        energyShift = Defaults.convertUnits("energy: to atomic", settings.energyShift)
        lines = ImpactExcitation.Line[]
        
        if settings.calcEffCollisionStrength || settings.calcRateCoefficient
            rateSettings = settings.rateSettings
            for  iLevel  in  initialMultiplet.levels
                for  fLevel  in  finalMultiplet.levels
                    if  Basics.selectLevelPair(iLevel, fLevel, settings.lineSelection)
                        ΔE = fLevel.energy - iLevel.energy
                        enGrid = Radial.GridGL("Finite", ΔE, ΔE * rateSettings.maxElectronEnergy, rateSettings.NoFreeElectronEnergy, printout=false)
                        for  (i, initialElectronEnergy) in enumerate( enGrid.t )         # initial electron energies
                            #initialElectronEnergy  = enGrid.t
                            finalElectronEnergy    = initialElectronEnergy - (fLevel.energy - iLevel.energy) + energyShift
                            if  finalElectronEnergy < 0    continue   end  
                            #channels = ImpactExcitation.determineChannels(fLevel, iLevel, settings) 
                            channels = ImpactExcitation.Channel[]
                            # order channels as per Kappa to check convergence
                            push!( lines, ImpactExcitation.Line(iLevel, fLevel, initialElectronEnergy, finalElectronEnergy, 0., 0., enGrid.wt[i], channels, 1.0) )
                        end
                    end
                end
            end
        else
            for  iLevel  in  initialMultiplet.levels
                for  fLevel  in  finalMultiplet.levels
                    if  Basics.selectLevelPair(iLevel, fLevel, settings.lineSelection)
                        for  en in settings.electronEnergies
                            initialElectronEnergy  = Defaults.convertUnits("energy: to atomic", en)
                            finalElectronEnergy    = initialElectronEnergy - (fLevel.energy - iLevel.energy) + energyShift
                            if  finalElectronEnergy < 0    continue   end  
                            #channels = ImpactExcitation.determineChannels(fLevel, iLevel, settings) 
                            channels = ImpactExcitation.Channel[]
                            # order channels as per Kappa to check convergence
                            push!( lines, ImpactExcitation.Line(iLevel, fLevel, initialElectronEnergy, finalElectronEnergy, 0., 0., 0., channels, 1.0) )
                        end
                    end
                end
            end
        end

        return( lines )
    end

    #SF: Please, full names in doc-strings ... ImpactExcitation.groupLines
    """
    `function groupLines(lines::Array{ImpactExcitation.Line,1})`
        ... groups lines having the same initial and final level but diferent energies
            returns an Array{Array{ImpactExcitation.Line,1},1}
    """
    function groupLines(lines::Array{ImpactExcitation.Line,1})
        indexPairs = Set{Tuple{Level, Level}}()

        for line in lines
            push!(indexPairs,(line.initialLevel, line.finalLevel))
        end

        groupLines = Array{ImpactExcitation.Line,1}[]

        for indexPair in indexPairs
            gl = ImpactExcitation.Line[]
            for line in lines
                if indexPair[1] == line.initialLevel && indexPair[2] == line.finalLevel
                    push!(gl, line)
                end
            end
            push!(groupLines, gl)
        end

        return groupLines
    end


    """
    `computeRateCoefficients(lines::Array{ImpactExcitation.Line, 1}, rateSettings::ImpactExcitation.RateSettings)`
        ... computes Exitation rate coefficients from the 
                and temperature [K]. All values are directly returned in [cm^3/s].
    """
    function computeRateCoefficients(lines::Array{ImpactExcitation.Line, 1}, rateSettings::ImpactExcitation.RateSettings)
        factor  = Defaults.convertUnits("length: from atomic to fm", 1.0)^3 * 1.0e-39 * 
                  Defaults.convertUnits("rate: from atomic to 1/s", 1.0) 
        gLines = groupLines(lines)

        allalphas = RateCoefficients[]

        for lines in gLines
            if length(lines) != rateSettings.NoFreeElectronEnergy error("error") end

            initialLevel = lines[1].initialLevel ; finalLevel = lines[1].finalLevel
            symi = LevelSymmetry(initialLevel.J, initialLevel.parity);    symf = LevelSymmetry(finalLevel.J, finalLevel.parity) 
            isE1Allowed = AngularMomentum.isAllowedMultipole(symi, EmMultipole("E1"), symf)
            
            alphas = Float64[]
            for temp in rateSettings.temperatures
                temp_au  = Defaults.convertUnits("temperature: from Kelvin to (Hartree) units", temp)
                wa = 0.0
                for (i, line) in enumerate(lines)
                    wa = wa + 2*2 / sqrt(2pi) / temp_au^(3/2) * factor * line.initialElectronEnergy * 
                                exp(-line.initialElectronEnergy / temp_au ) * line.weight * line.crossSection
                end
                push!(alphas, wa)
            end
            push!(allalphas, RateCoefficients( initialLevel, finalLevel, rateSettings.temperatures, alphas, zeros(length(rateSettings.temperatures)) ) )
        end

        return allalphas
    end


    """
    `computeEffCollisionStrength(lines::Array{ImpactExcitation.Line, 1}, rateSettings::ImpactExcitation.RateSettings)`
        ... computes Effective collision strengths from the calculated line collision strengths
                and temperature [K]. All values are directly returned in ....
    """
    function computeEffCollisionStrength(lines::Array{ImpactExcitation.Line, 1}, rateSettings::ImpactExcitation.RateSettings)
        gLines = groupLines(lines)

        allEffOmegas = RateCoefficients[]

        for lines in gLines
            if length(lines) != rateSettings.NoFreeElectronEnergy error("error") end

            initialLevel = lines[1].initialLevel ; finalLevel = lines[1].finalLevel
            symi = LevelSymmetry(initialLevel.J, initialLevel.parity);    symf = LevelSymmetry(finalLevel.J, finalLevel.parity) 
            isE1Allowed = AngularMomentum.isAllowedMultipole(symi, EmMultipole("E1"), symf)

            ΔE = (finalLevel.energy - initialLevel.energy) * 300
            
            effOmegas = Float64[]
            for temp in rateSettings.temperatures
                temp_au  = Defaults.convertUnits("temperature: from Kelvin to (Hartree) units", temp)

                wa = 0.0
                for (i, line) in enumerate(lines)
                    wa = wa + ( 1.0 / temp_au ) * line.collisionStrength * exp(-line.initialElectronEnergy / temp_au ) *   line.weight
                end

                a = lines[end].collisionStrength / log(lines[end].initialElectronEnergy)
                if isE1Allowed
                    wa += a / temp_au * ( log(ΔE^temp_au) / exp(ΔE/temp_au) - temp_au * SpecialFunctions.expinti(-ΔE/temp_au) )
                else
                    wa += a / temp_au * ( temp_au / exp(ΔE/temp_au) )
                end

                push!(effOmegas, wa)
            end
            push!(allEffOmegas, RateCoefficients( initialLevel, finalLevel, rateSettings.temperatures, zeros(length(rateSettings.temperatures)), effOmegas ) )
        end
        
        return allEffOmegas
    end


    """
    `ImpactExcitation.displayLines(lines::Array{ImpactExcitation.Line,1})`  
        ... to display a list of lines and channels that have been selected due to the prior settings. A neat table of all 
            selected transitions and energies is printed but nothing is returned otherwise.
    """
    function  displayLines(lines::Array{ImpactExcitation.Line,1})
        nx = 180
        println(" ")
        println("  Selected electron-impact ionization lines:")
        println(" ")
        println("  ", TableStrings.hLine(nx))
        sa = "  ";   sb = "  "
        sa = sa * TableStrings.center(18, "i-level-f"; na=2);                                sb = sb * TableStrings.hBlank(20)
        sa = sa * TableStrings.center(18, "i--J^P--f"; na=3);                                sb = sb * TableStrings.hBlank(22)
        sa = sa * TableStrings.center(12, "f--Energy--i"; na=4)               
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=5)
        sa = sa * TableStrings.center(12, "Energy e_in"; na=3);              
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=3)
        sa = sa * TableStrings.center(12, "Energy e_out"; na=4);              
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=4)
        sa = sa * TableStrings.flushleft(57, "List of partial waves and total symmetries"; na=4)  
        sb = sb * TableStrings.flushleft(57, "partial-in [total J^P] partial-out        "; na=4)
        println(sa);    println(sb);    println("  ", TableStrings.hLine(nx)) 
        #
        NoLines = 0   
        for  line in lines
            NoLines = NoLines + 1
            sa  = "  ";    isym = LevelSymmetry( line.initialLevel.J, line.initialLevel.parity)
                           fsym = LevelSymmetry( line.finalLevel.J,   line.finalLevel.parity)
            sa = sa * TableStrings.center(18, TableStrings.levels_if(line.initialLevel.index, line.finalLevel.index); na=2)
            sa = sa * TableStrings.center(18, TableStrings.symmetries_if(isym, fsym); na=4)
            en = line.finalLevel.energy - line.initialLevel.energy
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", en))                          * "    "
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.initialElectronEnergy))  * "    "
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.finalElectronEnergy))    * "    "
            kappaInOutSymmetryList = Tuple{Int64,Int64,LevelSymmetry}[]
            for  i in 1:length(line.channels)
                push!( kappaInOutSymmetryList, (line.channels[i].initialKappa, line.channels[i].finalKappa, line.channels[i].symmetry) ) 
            end
            wa = TableStrings.kappaKappaSymmetryTupels(95, kappaInOutSymmetryList)
            sb = sa * wa[1];    println( sb )  
            for  i = 2:length(wa)
                NoLines = NoLines + 1
                sb = TableStrings.hBlank( length(sa) ) * wa[i];    println( sb )
            end
            # Avoid long table printouts
            if NoLines > 100  println("\n  ImpactExcitation.displayLines():  A maximum of 100 lines are printed in this table. \n")
               break   
            end
        end
        println("  ", TableStrings.hLine(nx))
        #
        return( nothing )
    end


    """
    `ImpactExcitation.displayResults(lines::Array{ImpactExcitation.Line,1})`  
        ... to list all results, energies, cross sections, etc. of the selected lines. A neat table is printed but nothing is 
            returned otherwise.
    """
    function  displayResults(lines::Array{ImpactExcitation.Line,1})
        nx = 142
        println(" ")
        println("  Electron-impact excitation cross sections:")
        println(" ")
        println("  ", TableStrings.hLine(nx))
        sa = "  ";   sb = "  "
        sa = "  ";   sb = "  "
        sa = sa * TableStrings.center(18, "i-level-f"; na=2);                                sb = sb * TableStrings.hBlank(20)
        sa = sa * TableStrings.center(18, "i--J^P--f"; na=3);                                sb = sb * TableStrings.hBlank(22)
        sa = sa * TableStrings.center(12, "f--Energy--i"; na=4)               
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=5)
        sa = sa * TableStrings.center(12, "Energy e_in"; na=3);              
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=3)
        sa = sa * TableStrings.center(12, "Energy e_out"; na=3);              
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=3)
        sa = sa * TableStrings.center(15, "Cross section"; na=3)      
        #sb = sb * TableStrings.center(15, TableStrings.inUnits("cross section")*"*1E-8"; na=3)
        sb = sb * TableStrings.center(15, "10^(-20) m^2"; na=3)
        sa = sa * TableStrings.center(15, "Collision strength"; na=3)      
        sb = sb * TableStrings.center(15, " ";                  na=3)
        sa = sa * TableStrings.center(15, "Convergence"; na=3)      
        sb = sb * TableStrings.center(15, " ";                  na=3)
        println(sa);    println(sb);    println("  ", TableStrings.hLine(nx)) 
        #
        for  line in lines
            sa  = "  ";    isym = LevelSymmetry( line.initialLevel.J, line.initialLevel.parity)
                           fsym = LevelSymmetry( line.finalLevel.J,   line.finalLevel.parity)
            sa = sa * TableStrings.center(18, TableStrings.levels_if(line.initialLevel.index, line.finalLevel.index); na=2)
            sa = sa * TableStrings.center(18, TableStrings.symmetries_if(isym, fsym); na=4)
            en = line.finalLevel.energy - line.initialLevel.energy
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", en))                          * "    "
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.initialElectronEnergy))  * "    "
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.finalElectronEnergy))    * "     "
            sa = sa * @sprintf("%.6e", Defaults.convertUnits("cross section: from atomic", line.crossSection)*1e-8)    * "        "
            sa = sa * @sprintf("%.6e", line.collisionStrength)                                                    * "          "
            sa = sa * @sprintf("%.2e", line.convergence)                                                          * "    "
            println(sa)
        end
        println("  ", TableStrings.hLine(nx))
        #
        return( nothing )
    end


    """
    `displayLineResult(line::ImpactExcitation.Line)`
        ... to display energies, cross sections, collision stregths, convergence etc. for a single line immediatly after
         the calculation for that line is completed.
    """
    function displayLineResult(line::ImpactExcitation.Line)
        nx = 142
        println(" ")
        println("  Electron-impact excitation cross sections:")
        println(" ")
        println("  ", TableStrings.hLine(nx))
        sa  = "  ";    isym = LevelSymmetry( line.initialLevel.J, line.initialLevel.parity)
        fsym = LevelSymmetry( line.finalLevel.J,   line.finalLevel.parity)
        sa = sa * TableStrings.center(18, TableStrings.levels_if(line.initialLevel.index, line.finalLevel.index); na=2)
        sa = sa * TableStrings.center(18, TableStrings.symmetries_if(isym, fsym); na=4)
        en = line.finalLevel.energy - line.initialLevel.energy
        sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", en))                          * "    "
        sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.initialElectronEnergy))  * "    "
        sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", line.finalElectronEnergy))    * "     "
        sa = sa * @sprintf("%.6e", Defaults.convertUnits("cross section: from atomic", line.crossSection)*1e-8)    * "        "
        sa = sa * @sprintf("%.6e", line.collisionStrength)                                                    * "          "
        sa = sa * @sprintf("%.2e", line.convergence)                                                          * "    "
        println(sa)
        println("  ", TableStrings.hLine(nx))
        return( nothing )
    end


    """
    `ImpactExcitation.displayResults(allRates::Array{RateCoefficients,1})`  
        ... to list the excitation rate coefficients and effective collision strengths for the selected lines at the selected temperatures.
            A neat table is printed but nothing is returned otherwise.
    """
    function displayResults(allRates::Array{RateCoefficients,1})
        nx = 115
        println(" ")
        println("  Electron-impact excitation rate coefficients / effective collision strengths:")
        println(" ")
        println("  ", TableStrings.hLine(nx))
        sa = "      ";   sb = "  "
        sa = sa * TableStrings.center(14, "i-level-f"; na=2);                                sb = sb * TableStrings.hBlank(20)
        sa = sa * TableStrings.center(18, "i--J^P--f"; na=3);                                sb = sb * TableStrings.hBlank(22)
        sa = sa * TableStrings.center(12, "f--Energy--i"; na=4)               
        sb = sb * TableStrings.center(12, TableStrings.inUnits("energy"); na=4)
        sa = sa * TableStrings.center(14, "Temperature"; na=2) 
        sb = sb * TableStrings.center(12, "[K]"; na=5)
        sa = sa * TableStrings.center(12, "Rate Coeffs"; na=2) 
        sb = sb * TableStrings.center(12, "[cm^3/s]"; na=5)
        sa = sa * TableStrings.center(15, "Eff Coll Strength"; na=4) 
        println(sa);    println(sb);    println("  ", TableStrings.hLine(nx)) 

        for rates in allRates
            for (i, temp) in enumerate(rates.temperatures)
                sa  = "  ";    isym = LevelSymmetry( rates.initialLevel.J, rates.initialLevel.parity)
                               fsym = LevelSymmetry( rates.finalLevel.J,   rates.finalLevel.parity)
                sa = sa * TableStrings.center(18, TableStrings.levels_if(rates.initialLevel.index, rates.finalLevel.index); na=2)
                sa = sa * TableStrings.center(18, TableStrings.symmetries_if(isym, fsym); na=4)
                en = rates.finalLevel.energy - rates.initialLevel.energy
                sa = sa * @sprintf("%.6e", Defaults.convertUnits("energy: from atomic", en))                          * "      "
                sa = sa * @sprintf("%.4e", temp)         * "      "
                sa = sa * @sprintf("%.4e", rates.alphas[i])         * "       "
                sa = sa * @sprintf("%.4e", rates.effOmegas[i])         * "      "
                println(sa)
            end
        end
        
        println("  ", TableStrings.hLine(nx))
    end


end # module end
