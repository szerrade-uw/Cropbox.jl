# This unit simulates garlic leaf gas-exchange characteristics
# based on a coupled model of photosynthesis-stomatal conductance-energy balance
# See Kim and Lieth (2003) Ann. Bot for details

# gas-exchange parameter estimates for hardneck garlic 'Japanese Mountain' from outdoor plot experiments conducted in Seattle, WA in 2012. Sep 2012. SK

quadratic_solve_upper(a, b, c) = begin
    (a == 0) && return 0.
    v = b^2 - 4a*c
    (v < 0) ? -b/a : (-b + sqrt(v)) / 2a
end
quadratic_solve_lower(a, b, c) = begin
    (a == 0) && return 0.
    v = b^2 - 4a*c
    (v < 0) ? -b/a : (-b - sqrt(v)) / 2a
end

@system C3 begin
    intercellular_co2: Ci ~ hold
    effective_irradiance: I2 ~ hold
    leaf_temperature: T ~ hold
    absolute_leaf_temperature: Tk ~ hold

    ##############
    # Parameters #
    ##############

    # Arrhenius equation
    base_temperature: Tb => 25 ~ preserve(u"°C", parameter)
    absolute_base_temperature(Tb): Tbk ~ preserve(u"K", parameter)
    temperature_dependence_rate(T, Tk, Tb, Tbk; Ea(u"kJ/mol")): T_dep => begin
        exp(Ea * (T - Tb) / (Tbk * u"R" * Tk))
    end ~ call

    # Michaelis constant of rubisco for CO2 of C3 plants, ubar, from Bernacchi et al. (2001)
    rubisco_constant_for_co2_at_25: Kc25 => 404.9 ~ preserve(u"μbar", parameter)
    # Activation energy for Kc, Bernacchi (2001)
    activation_energy_for_co2: Eac => 79.43 ~ preserve(u"kJ/mol", parameter)
    rubisco_constant_for_co2(T_dep, Kc25, Eac): Kc => begin
        Kc25 * T_dep(Eac)
    end ~ track(u"μbar")

    # Michaelis constant of rubisco for O2, mbar, from Bernacchi et al., (2001)
    rubisco_constant_for_o2_at_25: Ko25 => 278.4 ~ preserve(u"mbar", parameter)
    # Activation energy for Ko, Bernacchi (2001)
    activation_energy_for_o2: Eao => 36.38 ~ preserve(u"kJ/mol", parameter)
    rubisco_constant_for_o2(T_dep, Ko25, Eao): Ko => begin
        Ko25 * T_dep(Eao)
    end ~ track(u"mbar")

    # mesophyll O2 partial pressure
    mesophyll_o2_partial_pressure: Om => 210 ~ preserve(u"mbar", parameter)

    # effective M-M constant for Kc in the presence of O2
    rubisco_constant_for_co2_with_o2(Kc, Om, Ko): Km => begin
        Kc * (1 + Om / Ko)
    end ~ track(u"μbar")

    dark_respiration_at_25: Rd25 => 1.08 ~ preserve(u"μmol/m^2/s" #= O2 =#, parameter)
    activation_energy_for_respiration: Ear => 49.39 ~ preserve(u"kJ/mol", parameter)
    dark_respiration(T_dep, Rd25, Ear): Rd => begin
        Rd25 * T_dep(Ear)
    end ~ track(u"μmol/m^2/s")
    #Rm(Rd) => 0.5Rd ~ track(u"μmol/m^2/s")

    triose_phosphate_limitation_at_25: TPU25 => 16.03 ~ preserve(u"μmol/m^2/s" #= CO2 =#, parameter)
    activation_energy_for_TPU: EaTPU => 47100 ~ preserve(u"J/mol", parameter)
    triose_phosphate_limitation(T_dep, TPU25, EaTPU): TPU => begin
        TPU25 * T_dep(EaTPU)
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    maximum_carboxylation_rate_at_25: Vcm25 => 108.4 ~ preserve(u"μmol/m^2/s" #= CO2 =#, parameter)
    activation_energy_for_carboxylation: EaVc => 52.1573 ~ preserve(u"kJ/mol", parameter)
    maximum_carboxylation_rate(T_dep, Vcm25, EaVc): Vcmax => begin
        Vcm25 * T_dep(EaVc)
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    maximum_electron_transport_rate_at_25: Jm25 => 169.0 ~ preserve(u"μmol/m^2/s" #= Electron =#, parameter)
    activation_energy_for_electron_transport: Eaj => 23.9976 ~ preserve(u"kJ/mol", parameter)
    electron_transport_temperature_response: Sj => 616.4 ~ preserve(u"J/mol/K", parameter)
    electron_transport_curvature: Hj => 200 ~ preserve(u"kJ/mol", parameter)
    maximum_electron_transport_rate(Tk, Tbk, T_dep, Jm25, Eaj, Sj, Hj): Jmax => begin
        R = u"R"
        Jm25 * begin
            T_dep(Eaj) *
            (1 + exp((Sj*Tbk - Hj) / (R*Tbk))) /
            (1 + exp((Sj*Tk  - Hj) / (R*Tk)))
        end
    end ~ track(u"μmol/m^2/s" #= Electron =#)

    # CO2 compensation point in the absence of day respiration, value from Bernacchi (2001)
    co2_compensation_point_at_25: Γ25 => 42.75 ~ preserve(u"μbar", parameter)
    activation_energy_for_co2_compensation_point: Eag => 37.83 ~ preserve(u"kJ/mol", parameter)
    co2_compensation_point(T_dep, Γ25, Eag): Γ => begin
        Γ25 * T_dep(Eag)
    end ~ track(u"μbar")

    #########
    # Rates #
    #########

    enzyme_limited_photosynthesis_rate(Vcmax, Ci, Γ, Km): Ac => begin
        Vcmax * (Ci - Γ) / (Ci + Km)
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    # θ: sharpness of transition from light limitation to light saturation
    light_transition_sharpness: θ => 0.7 ~ preserve(parameter)
    electron_transport_rate(I2, Jmax, θ): J => begin
        a = θ
        b = -(I2+Jmax) |> u"μmol/m^2/s" |> ustrip
        c = I2*Jmax |> u"(μmol/m^2/s)^2" |> ustrip
        quadratic_solve_lower(a, b, c)
    end ~ track(u"μmol/m^2/s")

    # light and electron transport limited A mediated by J
    transport_limited_photosynthesis_rate(J, Ci, Γ): Aj => begin
        J * (Ci - Γ) / 4(Ci + 2Γ)
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    triose_phosphate_limited_photosynthesis_rate(TPU): Ap => begin
        3TPU
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    gross_photosynthesis(Ac, Aj, Ap): A_gross => begin
        min(Ac, Aj, Ap)
    end ~ track(u"μmol/m^2/s" #= CO2 =#)

    net_photosynthesis(A_gross, Rd): A_net => begin
        # gets negative when PFD = 0, Rd needs to be examined, 10/25/04, SK
        A_gross - Rd
    end ~ track(u"μmol/m^2/s" #= CO2 =#)
end

@system BoundaryLayer begin
    weather ~ hold

    leaf_width: w => 0.1 ~ preserve(u"m", parameter)

    # maize is an amphistomatous species, assume 1:1 (adaxial:abaxial) ratio.
    stomatal_ratio: sr => 1.0 ~ preserve(parameter)
    sides_conductance_ratio(sr): scr => ((sr + 1)^2 / (sr^2 + 1)) ~ preserve

    # multiply by 1.4 for outdoor condition, Campbell and Norman (1998), p109
    outdoor_conductance_ratio: ocr => 1.4 ~ preserve

    wind_velocity(u=weather.wind): u => max(u, 0.1u"m/s") ~ track(u"m/s")
    # characteristic dimension of a leaf, leaf width in m
    characteristic_dimension(w): d => 0.72w ~ track(u"m")
    kinematic_viscosity_of_air_at_20: v => 1.51e-5 ~ track(u"m^2/s")
    thermal_diffusivity_of_air_at_20: κ => 21.5e-6 ~ track(u"m^2/s")
    reynolds_number(u, d, v): Re => u*d/v ~ track
    nusselt_number(Re): Nu => 0.60sqrt(Re) ~ track
    boundary_layer_heat_conductance(κ, Nu, d, scr, ocr, P_air=weather.P_air, Tk_air=weather.Tk_air): gh => begin
        g = (κ*Nu/d)
        # multiply by ratio to get the effective blc (per projected area basis), licor 6400 manual p 1-9
        g *= scr * ocr
        # including a multiplier for conversion from mm s-1 to mol m-2 s-1
        g * P_air / (u"R" * Tk_air)
    end ~ track(u"mmol/m^2/s")
    # 1.1 is the factor to convert from heat conductance to water vapor conductance, an avarage between still air and laminar flow (see Table 3.2, HG Jones 2014)
    boundary_layer_conductance(gh): gb => 0.147/0.135*gh ~ track(u"mol/m^2/s" #= H2O =#)
end

@system Stomata begin
    weather ~ hold
    soil ~ hold
    boundary_layer_conductance: gb ~ hold
    net_photosynthesis: A_net ~ hold
    co2_compensation_point: Γ ~ hold

    g0 => 0.096 ~ preserve(u"mol/m^2/s" #= H2O =#, parameter)
    g1 => 6.824 ~ preserve(parameter)

    diffusivity_ratio_boundary_layer: drb => 1.37 ~ preserve(#= u"H2O/CO2", =# parameter)
    diffusivity_ratio_air: dra => 1.6 ~ preserve(#= u"H2O/CO2", =# parameter)

    # surface CO2 in mole fraction
    co2_mole_fraction_at_leaf_surface(CO2=weather.CO2, drb, A_net, gb): Cs => begin
        CO2 - (drb * A_net / gb)
    end ~ track

    relative_humidity_at_leaf_surface(g0, g1, gb, m, A_net, Cs, RH=weather.RH): hs => begin
        a = m * g1 * A_net / Cs |> u"mol/m^2/s" |> ustrip
        b = g0 + gb - (m * g1 * A_net / Cs) |> u"mol/m^2/s" |> ustrip
        c = (-RH * gb) - g0 |> u"mol/m^2/s" |> ustrip
        #FIXME: check unit
        hs = quadratic_solve_upper(a, b, c)
        #TODO: need to prevent bifurcation?
        #clamp(hs, 0.1, 1.0)
    end ~ track(u"percent")

    # stomatal conductance for water vapor in mol m-2 s-1
    stomatal_conductance(g0, g1, m, A_net, hs, Cs): gs => begin
        gs = g0 + (g1 * m * (A_net * hs / Cs))
        max(gs, g0)
    end ~ track(u"mol/m^2/s" #= H2O =#)

    transpiration_reduction_factor: m => begin
        #TODO: implement soil water module
        1.0
    end ~ track

    total_conductance_h2o(gs, gb): gv => begin
        gs * gb / (gs + gb)
    end ~ track(u"mol/m^2/s" #= H2O =#)

    boundary_layer_resistance_co2(gb, drb): rbc => begin
        drb / gb
    end ~ track(u"m^2*s/mol")

    stomatal_resistance_co2(gs, dra): rsc => begin
        dra / gs
    end ~ track(u"m^2*s/mol")

    total_resistance_co2(rbc, rsc): rvc => begin
        rbc + rsc
    end ~ track(u"m^2*s/mol")
end

@system GasExchange(BoundaryLayer, Stomata, C3) begin
    weather ~ ::Weather(extern)
    soil ~ ::Soil(extern)

    co2_atmosphere(CO2=weather.CO2, P_air): Ca => (CO2 * P_air) ~ track(u"μbar")
    intercellular_co2_upper_limit(Ca): Cimax => 2Ca ~ track(u"μbar")
    intercellular_co2_lower_limit: Cimin => 0 ~ preserve(u"μbar")
    intercellular_co2(Ca, A_net, P_air, CO2=weather.CO2, rvc): Ci => begin
        Ca - A_net * rvc * P_air
    end ~ solve(lower=Cimin, upper=Cimax, u"μbar")

    #FIXME: confusion between PFD vs. PPFD
    photosynthetic_photon_flux_density: PPFD ~ track(u"μmol/m^2/s" #= Quanta =#, override)

    # leaf reflectance + transmittance
    leaf_scattering: δ => 0.15 ~ preserve(parameter)
    leaf_spectral_correction: f => 0.15 ~ preserve(parameter)

    absorbed_irradiance(PPFD, δ): Ia => begin
        PPFD * (1 - δ)
    end ~ track(u"μmol/m^2/s" #= Quanta =#)

    effective_irradiance(Ia, f): I2 => begin
        Ia * (1 - f) / 2 # useful light absorbed by PSII
    end ~ track(u"μmol/m^2/s" #= Quanta =#)

    leaf_thermal_emissivity: ϵ => 0.97 ~ preserve(parameter)
    stefan_boltzmann_constant: sbc => u"σ" ~ preserve(u"W/m^2/K^4", parameter)
    latent_heat_of_vaporiztion_at_25: λ => 44 ~ preserve(u"kJ/mol", parameter)
    specific_heat_of_air: Cp => 29.3 ~ preserve(u"J/mol/K", parameter)

    # psychrometric constant (C-1) ~ 6.66e-4
    psychometric_constant(Cp, λ): psc => (Cp / λ) ~ preserve(u"K^-1")

    # apparent psychrometer constant
    apparent_psychometric_constant(psc, ghr, gv): psc1 => (psc * ghr / gv) ~ preserve(u"K^-1")

    # see Campbell and Norman (1998) pp 224-225
    # because Stefan-Boltzman constant is for unit surface area by denifition,
    # all terms including sbc are multilplied by 2 (i.e., gr, thermal radiation)
    leaf_surface_radiative_conductance(Tk, ϵ, sbc, Cp): gr => begin
        # radiative conductance, 2 account for both sides
        g = 4ϵ*sbc*Tk^3 / Cp
        2g
    end ~ track(u"mmol/m^2/s" #= H2O =#)

    total_radiative_conductance(gh, gr): ghr => gh + gr ~ track(u"mmol/m^2/s" #= H2O =#)

    radiation_conversion_factor: k => (1 / 4.55) ~ preserve(u"J/μmol")
    photosynthetically_active_radiation(PPFD, k): PAR => (PPFD * k) ~ track(u"W/m^2")

    near_infrared_radiation(PAR): NIR => begin
        # If total solar radiation unavailable, assume NIR the same energy as PAR waveband
        PAR
    end ~ track(u"W/m^2")

    # solar radiation absorptivity of leaves: =~ 0.5
    absorption_coefficient: α => 0.5 ~ preserve(parameter)

    radiation_absorbed_from_light(PAR, NIR, α, δ): R_light => begin
        # shortwave radiation (PAR (=0.85) + NIR (=0.15))
        α*((1-δ)*PAR + δ*NIR)
    end ~ track(u"W/m^2")

    radiation_absorbed_from_wall(ϵ, sbc, Tk_air): R_wall => begin
        ϵ*sbc*Tk_air^4
    end ~ track(u"W/m^2")

    radiation_absored(R_light, R_wall): R_in => begin
        # times 2 for projected area basis
        2(R_light + R_wall)
    end ~ track(u"W/m^2")

    radiation_emitted(ϵ, sbc, Tk): R_out => begin
        2(ϵ*sbc*Tk^4)
    end ~ track(u"W/m^2")

    net_radiation_absorbed(R_in, R_out): R_net => R_in - R_out ~ track(u"W/m^2")

    latent_heat_flux(λ, gv, VPD=weather.VPD, P_air): λE => begin
        λ*gv*VPD / P_air
    end ~ track(u"W/m^2")

    #FIXME: come up with a better name? (i.e. heat capacity = J(/kg)/K))
    sensible_heat_capacity(Cp, ghr, λ, gv, VPD_slope=weather.VPD_slope): C => begin
        Cp*ghr + λ*gv*VPD_slope
    end ~ track(u"W/m^2/K")

    temperature_adjustment(R_net, λE, C): T_adj => begin
        # eqn 14.6b linearized form using first order approximation of Taylor series
        #(psc1 / (VPD_slope + psc1)) * (R_net / (Cp*ghr) - VPD/(psc1*P_air))
        (R_net - λE) / C
    end ~ solve(lower=-10u"K", upper=10u"K", u"K")

    air_temperature(weather.T_air): T_air ~ track(u"°C")
    absolute_air_temperature(weather.Tk_air): Tk_air ~ track(u"K")
    air_pressure(weather.P_air): P_air ~ track(u"kPa")

    leaf_temperature(T_adj, T_air): [T, T_leaf] => T_air + T_adj ~ track(u"°C")
    absolute_leaf_temperature(T_leaf): Tk ~ track(u"K")

    evapotranspiration(gv, T_leaf, T_air, P_air, RH=weather.RH, ea=weather.vp.ambient, es=weather.vp.saturation): ET => begin
        Ea = ea(T_air, RH)
        Es = es(T_leaf)
        ET = gv * ((Es - Ea) / P_air) / (1 - (Es + Ea) / P_air)
        max(ET, zero(ET)) # 04/27/2011 dt took out the 1000 everything is moles now
    end ~ track(u"mmol/m^2/s" #= H2O =#)
end