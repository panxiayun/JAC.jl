
"""
`module  JAC.FormFactor`  ... a submodel of JAC that contains all methods for computing atomic form factors for some level; 
                              it is using JAC, JAC.ManyElectron, JAC.Radial.
"""
module FormFactor

    using Printf, JAC, JAC.ManyElectron, JAC.Radial
    global JAC_counter = 0


    """
    `struct  FormFactor.Settings`  ... defines a type for the details and parameters of computing alpha-variation parameters.

        + qList                    ::Array{Float64,1} ... List of q-values in [a.u.]
        + printBeforeComputation   ::Bool             ... True if a list of selected levels is printed before the actual computations start. 
        + selectLevels             ::Bool             ... True if individual levels are selected for the computation.
        + selectedLevels           ::Array{Level,1}   ... List of selected levels.
    """
    struct Settings 
        qList                      ::Array{Float64,1} 
        printBeforeComputation     ::Bool
        selectLevels               ::Bool
        selectedLevels             ::Array{Level,1}
    end 


    """
    `JAC.FormFactor.Settings()`  ... constructor for an `empty` instance of FormFactor.Settings for the computation of atomic form factors.
    """
    function Settings()
        Settings(Float64[0., 0.1, 1.0, 10.], false, false, Level[])
    end


    # `Base.show(io::IO, settings::FormFactor.Settings)`  ... prepares a proper printout of the variable settings::FormFactor.Settings.
    function Base.show(io::IO, settings::FormFactor.Settings) 
        println(io, "qList:                    $(settings.qList)  ")
        println(io, "printBeforeComputation:   $(settings.printBeforeComputation)  ")
        println(io, "selectLevels:             $(settings.selectLevels)  ")
        println(io, "selectedLevels:           $(settings.selectedLevels)  ")
    end


    
    """
    `struct  FormFactor.Outcome`  ... defines a type to keep the outcome of a form-factor computation, such as the standard form factor
                                      as well other results.

        + level                     ::Level              ... Atomic level to which the outcome refers to.
        + qValues                   ::Array{Float64,1}   ... momentum transfer |q|.
        + standardFs                ::Array{Float64,1}   ... standard atomic form factor F(q) for an (assumed) spherical charge distribution.
        + modifiedFs                ::Array{Float64,1}   ... modified atomic form factor F(q) for an (assumed) spherical charge distribution.
    """
    struct Outcome 
        level                       ::Level 
        qValues                     ::Array{Float64,1}
        standardFs                  ::Array{Float64,1}
        modifiedFs                  ::Array{Float64,1} 
    end 


    """
    `JAC.FormFactor.Outcome()`  ... constructor for an `empty` instance of FormFactor.Outcome for the computation of atomic form factors.
    """
    function Outcome()
        Outcome(Level(), Float64[], Float64[], Float64[])
    end


    # `Base.show(io::IO, outcome::FormFactor.Outcome)`  ... prepares a proper printout of the variable outcome::FormFactor.Outcome.
    function Base.show(io::IO, outcome::FormFactor.Outcome) 
        println(io, "level:                   $(outcome.level)  ")
        println(io, "qValues:                 $(outcome.qValues)  ")
        println(io, "standardFs:              $(outcome.standardFs)  ")
        println(io, "modifiedFs:              $(outcome.modifiedFs)  ")
    end


    """
    `JAC.FormFactor.amplitude(q::Float64, finalLevel::Level, initialLevel::Level, grid::Radial.Grid; display::Bool=false)`  
         ... to compute the momentum transfer amplitude  <(alpha_f J_f, kappa) J_i || T^(1) || alpha_i J_i>  
         for the given final and initial level. A value::ComplexF64 is returned.
    """
    function amplitude(q::Float64, finalLevel::Level, initialLevel::Level, grid::Radial.Grid; display::Bool=false)
        nf = length(finalLevel.basis.csfs);    ni = length(initialLevel.basis.csfs)
        printstyled("Compute (single-electron) momentum transfer matrix of dimension $nf x $ni in the final- and initial-state bases " *
                    "for the transition [$(initialLevel.index)- $(finalLevel.index)] ... ", color=:light_green)
        matrix = zeros(ComplexF64, nf, ni)
        #
        #
        printstyled("done. \n", color=:light_green)
        printstyled("\nWarning -- FormFactor.amplitude():: Not yet implemented.", color=:cyan)
        #
        amplitude = 4.0 + 5.0*im
        #
        if  display
            println("   (Single-electron) Momentum transfer amplitude:  "                                                 *
                    "< level=$(finalLevel.index) [J=$(finalLevel.J)$(string(finalLevel.parity))] || T^(1) ($q a.u.) ||"   *
                    " $(initialLevel.index) [$(initialLevel.J)$(string(initialLevel.parity))] >  = $amplitude  ")
        end
        
        return( amplitude )
    end


    """
    `JAC.FormFactor.standardF(q::Float64, level::Level, grid::Radial.Grid)`  
         ... to compute the (real) Fourier transform of the (spherically-symmetric) charge distribution. A value::Float64 is returned.
    """
    function standardF(q::Float64, level::Level, grid::Radial.Grid)
        wa = zeros( grid.nr )
        # Compute the total density
        for  sh in level.basis.subshells
            occ  = JAC.computeMeanSubshellOccupation(sh, [level])
            orb  = level.basis.orbitals[sh]
            nrho = length(orb.P)
            for    i = 1:nrho   wa[i] = wa[i] + occ * (orb.P[i]^2 + orb.Q[i]^2)    end
        end
        # Compute the full integrant; the factor 4pi * r^2 is already in the density
        if     q == 0.   
        else             for    i = 2:grid.nr   wa[i] = wa[i] / grid.r[i] * sin(q*grid.r[i]) / q    end
        end
        sF = JAC.RadialIntegrals.V0(wa, grid.nr, grid::Radial.Grid)
        
        return( sF )
    end


    """
    `JAC.FormFactor.modifiedF(q::Float64, level::Level, grid::Radial.Grid)`  
         ... to compute the (real) Fourier transform of the (spherically-symmetric) charge distribution but including a correction
             due to the local (DFS) potential, relative to the rest mass of the electron. A value::Float64 is returned.
    """
    function modifiedF(q::Float64, level::Level, grid::Radial.Grid)
        wa  = zeros( grid.nr )
        wc  = JAC.give("speed of light: c")
        pot = JAC.compute("radial potential: Dirac-Fock-Slater", grid, level)
        # Compute the total density
        for  sh in level.basis.subshells
            occ  = JAC.computeMeanSubshellOccupation(sh, [level])
            orb  = level.basis.orbitals[sh]
            ei   = abs(orb.energy)
            nrho = length(orb.P)
            #
            for    i = 2:nrho 
                wx = wc^2 / (wc^2 + ei + pot.Zr[i]/grid.r[i])
                if     q == 0.   wa[i] = wa[i] + occ * (orb.P[i]^2 + orb.Q[i]^2) * wx
                else             wa[i] = wa[i] + occ * (orb.P[i]^2 + orb.Q[i]^2) / grid.r[i] * sin(q*grid.r[i]) / q * wx
                end
            end
        end
        mF = JAC.RadialIntegrals.V0(wa, grid.nr, grid::Radial.Grid)
        
        return( mF )
    end


    """
    `JAC.FormFactor.computeAmplitudesProperties(outcome::FormFactor.Outcome, nm::JAC.Nuclear.Model, grid::Radial.Grid, settings::FormFactor.Settings)`  
         ... to compute all form factors, etc. for the given outcome; a newOutcome::FormFactor.Outcome is returned.
    """
    function computeAmplitudesProperties(outcome::FormFactor.Outcome, nm::JAC.Nuclear.Model, grid::Radial.Grid, settings::FormFactor.Settings)
        standardFs = Float64[];    modifiedFs = Float64[]
        for  i = 1:length(outcome.qValues)
            sF = FormFactor.standardF(outcome.qValues[i]::Float64, outcome.level::Level, grid::Radial.Grid)
            mF = FormFactor.modifiedF(outcome.qValues[i]::Float64, outcome.level::Level, grid::Radial.Grid)
            push!( standardFs, sF);    push!( modifiedFs, mF)
        end
        newOutcome = JAC.FormFactor.Outcome(outcome.level, outcome.qValues, standardFs, modifiedFs)
        return( newOutcome )
    end


    """
    `JAC.FormFactor.computeOutcomes(multiplet::Multiplet, nm::JAC.Nuclear.Model, grid::Radial.Grid, settings::FormFactor.Settings; output=true)` 
         ... to compute (as selected) the alpha-variation parameters for the levels of the given multiplet and as specified by the given settings. 
         The results are printed in neat tables to screen but nothing is returned otherwise.
    """
    function computeOutcomes(multiplet::Multiplet, nm::JAC.Nuclear.Model, grid::Radial.Grid, settings::FormFactor.Settings; output=true)
        println("")
        printstyled("JAC.FormFactor.computeOutcomes(): The computation of the atomic form factors starts now ... \n", color=:light_green)
        printstyled("------------------------------------------------------------------------------------------- \n", color=:light_green)
        #
        outcomes = JAC.FormFactor.determineOutcomes(multiplet, settings)
        # Display all selected levels before the computations start
        if  settings.printBeforeComputation    JAC.FormFactor.displayOutcomes(outcomes)    end
        # Calculate all amplitudes and requested properties
        newOutcomes = FormFactor.Outcome[]
        for  outcome in outcomes
            ##x standardFs = Float64[];    modifiedFs = Float64[]
            newOutcome = JAC.FormFactor.computeAmplitudesProperties(outcome, nm, grid, settings) 
            push!( newOutcomes, newOutcome)
        end
        # Print all results to screen
        JAC.FormFactor.displayResults(stdout, newOutcomes)
        printSummary, iostream = JAC.give("summary flag/stream")
        if  printSummary    JAC.FormFactor.displayResults(iostream, newOutcomes)   end
        #
        if    output    return( newOutcomes )
        else            return( nothing )
        end
    end


    """
    `JAC.FormFactor.determineOutcomes(multiplet::Multiplet, settings::FormFactor.Settings)`  ... to determine a list of Outcomes's for 
         the computation of the alpha-variation parameters for the given multiplet. It takes into account the particular selections and 
         settings. An Array{FormFactor.Outcome,1} is returned. Apart from the level specification, all physical properties are set to zero 
         during the initialization process.
    """
    function  determineOutcomes(multiplet::Multiplet, settings::FormFactor.Settings) 
        if    settings.selectLevels   selectLevels   = true;   selectedLevels = copy(settings.selectedLevels)
        else                          selectLevels   = false
        end
    
        outcomes = FormFactor.Outcome[]
        for  i = 1:length(multiplet.levels)
            if  selectLevels  &&  !(haskey(selectedLevels, i))    continue   end
            push!( outcomes, FormFactor.Outcome(multiplet.levels[i], settings.qList, Float64[], Float64[] ) )
        end
        return( outcomes )
    end


    """
    `JAC.FormFactor.displayOutcomes(outcomes::Array{FormFactor.Outcome,1})`  ... to display a list of levels that have been selected 
         for the computations. A small neat table of all selected levels and their energies is printed but nothing is returned otherwise.
    """
    function  displayOutcomes(outcomes::Array{FormFactor.Outcome,1})
        println(" ")
        println("  Selected FormFactor levels:")
        println(" ")
        println("  ", JAC.TableStrings.hLine(86))
        sa = "  ";   sb = "  "
        sa = sa * JAC.TableStrings.center(10, "Level"; na=2);                             sb = sb * JAC.TableStrings.hBlank(12)
        sa = sa * JAC.TableStrings.center(10, "J^P";   na=4);                             sb = sb * JAC.TableStrings.hBlank(14)
        sa = sa * JAC.TableStrings.center(14, "Energy"; na=4);              
        sb = sb * JAC.TableStrings.center(14, JAC.TableStrings.inUnits("energy"); na=4)
        sa = sa * "  q-values  ...";                                                      sb = sb * "   [a.u.]"
        println(sa);    println(sb);    println("  ", JAC.TableStrings.hLine(86)) 
        #  
        for  outcome in outcomes
            sa  = "  ";    sym = LevelSymmetry( outcome.level.J, outcome.level.parity)
            sa = sa * JAC.TableStrings.center(10, JAC.TableStrings.level(outcome.level.index); na=2)
            sa = sa * JAC.TableStrings.center(10, string(sym); na=4)
            sa = sa * @sprintf("%.8e", JAC.convert("energy: from atomic", outcome.level.energy)) * "    "
            if  length(outcome.qValues) >= 1   sa = sa * @sprintf("%.2e", outcome.qValues[1] ) * ",  "   end
            if  length(outcome.qValues) >= 2   sa = sa * @sprintf("%.2e", outcome.qValues[2] ) * ",  "   end
            if  length(outcome.qValues) >= 3   sa = sa * @sprintf("%.2e", outcome.qValues[3] ) * ",  "   end
            if  length(outcome.qValues) >  3   sa = sa * "...    "   else   sa = sa * "    "             end
            println( sa ) 
        end
        println("  ", JAC.TableStrings.hLine(86))
        #
        return( nothing )
    end


    """
    `JAC.FormFactor.displayResults(stream::IO, outcomes::Array{FormFactor.Outcome,1})`  ... to display the energies, M_ms and F-parameters, etc. for the 
         selected levels. A neat table is printed but nothing is returned otherwise.
    """
    function  displayResults(stream::IO, outcomes::Array{FormFactor.Outcome,1})
        println(stream, " ")
        println(stream, "  Standard and modified atomic form factors [note F^(standard) (0) = N_e]:")
        println(stream, " ")
        println(stream, "  ", JAC.TableStrings.hLine(88))
        sa = "  ";   sb = "  "
        sa = sa * JAC.TableStrings.center(10, "Level"; na=2);                             sb = sb * JAC.TableStrings.hBlank(12)
        sa = sa * JAC.TableStrings.center(10, "J^P";   na=4);                             sb = sb * JAC.TableStrings.hBlank(14)
        sa = sa * JAC.TableStrings.center(14, "Energy"; na=3)              
        sb = sb * JAC.TableStrings.center(14, JAC.TableStrings.inUnits("energy"); na=3)
        sa = sa * JAC.TableStrings.center(14, "q [a.u.]";       na=1) 
        sa = sa * JAC.TableStrings.center(14, "standard F";     na=1) 
        sa = sa * JAC.TableStrings.center(14, "modified F";     na=4) 
        sb = sb * JAC.TableStrings.center(14, "    " ; na=4)
        println(stream, sa);    println(stream, sb);    println(stream, "  ", JAC.TableStrings.hLine(88)) 
        #  
        for  outcome in outcomes
            sa  = "  ";    sym = LevelSymmetry( outcome.level.J, outcome.level.parity)
            sa = sa * JAC.TableStrings.center(10, JAC.TableStrings.level(outcome.level.index); na=2)
            sa = sa * JAC.TableStrings.center(10, string(sym); na=4)
            sa = sa * @sprintf("%.8e", JAC.convert("energy: from atomic", outcome.level.energy)) * "    "
            sa = sa * @sprintf("%.5e", outcome.qValues[1])                                       * "    "
            sa = sa * @sprintf("%.5e", outcome.standardFs[1])                                    * "    "
            sa = sa * @sprintf("%.5e", outcome.modifiedFs[1])                                    * "    "
            println(stream, sa )
            for  i = 2:length(outcome.qValues)
                sa = repeat(" ", 47)
                sa = sa * @sprintf("%.5e", outcome.qValues[i])                                   * "    "
                sa = sa * @sprintf("%.5e", outcome.standardFs[i])                                * "    "
                sa = sa * @sprintf("%.5e", outcome.modifiedFs[i])                                * "    "
                println(stream, sa )
            end
        end
        println(stream, "  ", JAC.TableStrings.hLine(88), "\n\n")
        #
        return( nothing )
    end



end # module
