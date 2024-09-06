using PMTSimulation
using CairoMakie
using Distributions
using Random
using StaticArrays
using DSP
using Profile
using DataFrames
import Pipe: @pipe
using PoissonRandom
using Format
using Unitful
using PhysicalConstants.CODATA2018
using Roots
using Base.Iterators
using Random
using Interpolations
using PhysicsTools
using Plots
using CSV

ElementaryCharge * 5E6 / 5u"ns" * 50u"Ω" |> u"mV"
fwhm = 6.0
gumbel_scale = gumbel_width_from_fwhm(6)
gumbel_loc = 10
spe_d = make_spe_dist(pmt_config.spe_template)
adc_range = (0.0, 1000.0)
adc_bits = 12

adc_noise_level = 0.6

noise_amp = find_noise_scale(adc_noise_level, adc_range, adc_bits)

pmt_config = PMTConfig(
    st=ExponTruncNormalSPE(expon_rate=1.0, norm_sigma=0.3, norm_mu=1.0, trunc_low=0.0, peak_to_valley=3.1),
    pm=PDFPulseTemplate(
        dist=Truncated(Gumbel(0, gumbel_scale) + gumbel_loc, 0, 30),
        amplitude=7.0 # mV
    ),
    #snr_db=22.92,
    noise_sigma=noise_amp,
    sampling_freq=2.0,
    unf_pulse_res=0.1,
    adc_freq=0.200,
    adc_bits=12,
    adc_dyn_range=(0.0, 1000.0), #mV
    lp_cutoff=0.1,
    tt_mean=25, # TT mean
    tt_fwhm=1.5 # TT FWHM
)
df = CSV.read("/Users/vincentgousy-leblanc/Documents/GitHub/PMT_waveform_gen/muon_data/muon.csv", DataFrame)

#result = df[df.age .> 30, [:name, :salary]]
df_2 = DataFrame(PMT = [], time_over =[],charge_depo=[],time_even=[]) 
P = Plots.plot()
for i in 0:15
    result = df[occursin.("PMT", df.out_VolumeName) .& (df.out_Volume_CopyNo .== i), :]
    println(size(result[!,:out_t]))
    if isempty(result[!,:out_t])
        continue
    end
    time_serie=result[!,:out_t] .- 150
    diff_time=apply_tt(time_serie, pmt_config.tt_dist)
    c = rand(spe_d,size(time_serie))
    pulses = PulseSeries(diff_time, c, pmt_config.pulse_model)
    println(pulses)
    waveform = Waveform(pulses, pmt_config.sampling_freq, pmt_config.noise_amp)
    tot,charge_test,timing=time_over_threshold(waveform)
    new_df = DataFrame(PMT = [i for x in tot], time_over = [x for x in tot],charge_depo=[x for x in charge_test],time_even=[x for x in timing])
    df_2=vcat(df_2,new_df)
    #append!(df_2.PMT,[i])
    #append!(df_2.time_over,[tot])
    #append!(df_2.charge_depo,[charge_test])
    #append!(df_2.time_even,[timing])
    #df_2 = DataFrame(PMT = [i], time_over =[tot],charge_depo=[charge_test],time_even=[timing])
    println(df_2)
    Plots.plot!(P,waveform.timestamps,waveform.values,title="Waveforms generated by a muon",label="PMT"*string(i),xlabel="Time[nsec]",ylabel="mV",xlims=(50,120))
    display(P)
end
CSV.write("test.csv", df_2)


#Make a SPE distribution
spe_d = make_spe_dist(pmt_config.spe_template)
lines(0:0.01:5, x -> pdf(spe_d, x), axis=(; title="SPE Distribution", xlabel="Charge (PE)", ylabel="PDF"))

pulse_times=[1,1,2,3,20,30,7,40,1]
pulse_charges = [0.1, 0.3, 1, 5, 6, ]
diff_time=apply_tt(pulse_times, pmt_config.tt_dist)
println(diff_time)


c = rand(spe_d,size(time_serie))
pulses = PulseSeries(diff_time, c, pmt_config.pulse_model)
waveform = Waveform(pulses, pmt_config.sampling_freq, pmt_config.noise_amp)
lines(waveform.timestamps, waveform.values, axis=(; xlabel="Time (ns)", ylabel="Amplitude (mV)"))

threshold=3
tot,charge_test,timing=time_over_threashold(waveform)
bool_array = waveform.values .> threshold
# Step 2: Calculate the difference between consecutive elements
diff_bool = diff_bool = vcat(false, diff(bool_array))#diff(bool_array)
bool_diff = diff_bool .!= 0
P = Plots.plot()
Plots.scatter!(P,waveform.timestamps[bool_diff],waveform.values[bool_diff])
Plots.plot!(P,waveform.timestamps,waveform.values)