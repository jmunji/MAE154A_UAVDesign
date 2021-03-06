%Thomas Kantner
%MAE 154A UAV Design Verification

%This master script takes the design layout input parameters (size,
%power train, etc), randomizes them, and runs calculations to determine 
%whether the design meets the mission specifications and is a stable and 
%reasonable system. If it is, then we save to an excel file 

clear; close all; clc;

%Import the spreadsheets for structs
engines = xlsread('Engine_Database.xlsx'); %Remember to assort by increasing
avionics = xlsread('Avionics_Weight_Budget.xlsx');
controls = xlsread('Control_Weight_Budget.xlsx');

%Physical constants
rho_10k = 17.56e-4; %Atmos. Density at 10k ft [slugs/ft^3]
rho_sl = 23.77e-4; %Atmos. Density at sl [slugs/ft^3]

%Mission Specs -> used to verify design
endur = 2; %Endurance [hrs]
RC = 1500;  %Rate of Climb [fpm]
RC = RC/60; %Rate of Climb [fps]
R_cruise = 60; %Cruising 
ceil = 10000; %Ceiling [ft]
v_max_sl = 150;  %Max Speed @ SL [mph]
v_max_sl = v_max_sl*5280/3600; %Max speed @ SL [fps]
v_max_10k = 180;  %Max Speed @ 10k [mph]
v_max_10k = v_max_10k*5280/3600; %Max speed @ 10k [fps]
v_stall = 80; %Stall speed @ 10k [mph]
v_stall = v_stall*5280/3600; %Stall speed @ 10k [fps]
W_max = 300;   %Max weight [lbs]
W_payload = avionics(size(avionics)); %Weight of the payload [lbs]
CD_0 = 0.04; %Estimate for now, refine later 

%Cruise Conditions - On our way to the fire
eta_p_cruise = 0.85;  %Cruise Propulsive efficiency [-]
c_p_cruise_bhp = 0.7;   %Sp. Fuel Consumption [lbs/hp/hr] -> How to determine this

%Loiter conditions
eta_p_loit = 0.85;   %Loiter Propulsive efficiency [-]
c_p_loit_bhp = 0.5;   %Sp. Fuel Consumption [lbs/hp/hr] -> How to determine this

%Takeoff, Climb, and Landing Fractions - Raymer
W_fuel_to_frac = 0.970;  %Takeoff fuel weight fraction [-]
W_fuel_climb_frac = 0.985; %Climb fuel weight fraction [-]
W_fuel_land_frac = 0.995;  %Landing fuel weight fraction [-]

%Number of Good and Bad Designs
n_good = 0;
n_bad = 0;

%Randomly generate designs
for n = 1:100

%Randomly Generate a Design
W_i = 20; %Initial Weight guess [lbs]
S_w = 1 + rand*3;  %Wing Surface Area [ft^2]
b_w = 2 + rand*4;  %Wingspan [ft]
e = 0.7; %Rectangular wing efficiency [-]
lam_1_4 = 0; %Wing Quarter chord sweep [rad]
lam = 1;   %Taper ratio [-]
thicc = .12; %Max chord thickness ratio [-]
N = 4;  %Ultimate load factor (fixed) [-]
L_fuse = 2.5 + rand*2; %Length of fuselage [ft]
Wid_fuse = .5 + rand*.5;  %Width of fuselage [ft]
D_fuse = .5 + rand*.5; %Depth of fuselage [ft]
S_ht = .5 + rand*.5; %Horizontal tail surface area [ft^2]
l_t = 1.5 + rand*1.5; %Distance from wing 1/4 MAC to tail 1/4 MAC [ft]
b_h = .5 + rand*.5; %Horizontal tail span [ft]
S_vt = .5 + rand*.5; %Vertical tail surface area [ft^2] 
b_v = .5 + rand*.5; %Vertical tail span [ft]
chord = S_w/b_w;  %Chord length [ft]
i_t = rand*4;  %Tail Incidence Angle [deg]
i_t = i_t*pi/180; %Tail Incidence angle [rad]
chord_f = .1 + .9*rand; %Flap chord Length [ft]
A = b_w^2/S_w; % Aspect Ratio [-]
C_m = S_w/b_w; %Mean aerodynamic chord [ft]

%---------------------------Weight Calculations --------------------------%

k = 0;
max_iter = 50;
W_thresh = 0.1; %Weight threshold for convergence [lbs]
while(k < max_iter)
    %Drag calculations
    K = 1/(pi*A*e);
    v_sl = linspace(50,v_max_sl); % Velocity vector at sea level [fps]
    v_10k = linspace(v_stall, v_max_10k);  %Velocity vector at 10k [fps]
    
    D_para_sl = .5*rho_sl*v_sl.^2*S_w.*CD_0; %Parasitic drag sl [lbf]
    D_para_10k = .5*rho_10k*v_10k.^2*S_w.*CD_0; %Parasitic drag at 10k ft [lbf]

    D_i_sl = 2*K*W_i^2./(rho_sl*v_sl.^2*S_w); %Induced Drag sl [lbf]
    D_i_10k = 2*K*W_i^2./(rho_10k*v_10k.^2*S_w); %Induced drag at 10k ft[lbf]

    D_tot_sl = D_para_sl + D_i_sl; %Total drag at sl [lbf]
    D_tot_10k = D_para_10k + D_i_10k; %Total drag at 10k ft [lbf]
    
    %Find Best ratios for loiter and cruise
    [L32_D_loit, i_loit] = max((W_i./(.5*rho_10k.*v_10k.^2*S_w))...
        .^(3/2)./(D_tot_10k./(.5*rho_10k.*v_10k.^2*S_w))); %Get max L^(3/2)/D and indice of loiter [-]
    L_D_loit = W_i/D_tot_10k(i_loit); %Get L/D at loiter [-]
    v_loit = v_10k(i_loit); %Loiter velocity [fps]
    [L_D_cr, i_cr] = max(W_i./D_tot_10k); %Get max L/D and indice of cruise [-]
    v_cruise = v_10k(i_cr); %Cruise velocity [fps]
    
    %Fuel Calculations - Raymner
    c_p_cruise = c_p_cruise_bhp*v_cruise/(550*eta_p_cruise); %Convert units and add vel [-]
    W_fuel_cruise_frac = exp(-(R_cruise/2)*c_p_cruise/(L_D_cr*v_cruise)); %Crusing fraction [-]
    c_p_loit = c_p_loit_bhp*v_cruise/(550*eta_p_loit); %Convert units and add vel [-]
    W_fuel_loit_frac = exp(-endur*c_p_loit/L_D_loit);  %Fuel-Weight fraction used in loiter [-]
    Misn_fuel_frac = W_fuel_to_frac * W_fuel_climb_frac * W_fuel_cruise_frac^2 *...
        W_fuel_loit_frac * W_fuel_land_frac; %Total fuel-weight fraction [-]
    W_fuel = (1-Misn_fuel_frac)*W_i*1.05; %Total weight of fuel req + 5% [lbs]
    
    %Structure Weight Calculations (Cessna Eqs)
    B = W_i*N*S_w*(1.9*A - 4)/(1 + .11*thicc);
    W_wing = 69*(B*10^-6)^.69; %Weight of the wing [lbs]
    W_fuse = .11*W_i; %Weight of the fuselage [lbs]
    W_htail = 1.2*(W_i/3000)^.25*S_ht;  %Weight of Horizontal tail [lbs]
    W_vtail = 1.28*S_vt; %Weight of Vertical tail [lbs]
    
    %Power calculations
    P_ex = RC*W_i; %Excess power [ft*lbs/s]
    P_ex = P_ex/550; %Excess power [hp]
    
    P_req_10k = D_tot_10k.*v_10k; %Power required @ 10k [ft*lbs/s]
    P_req_10k = P_req_10k/550;  %Power required @ 10k[hp]
    
    P_req_sl = D_tot_sl.*v_sl; %Power required @ SL [ft*lbs/s]
    P_req_sl = P_req_sl/550;  %Power required @ SL [hp]
    P_av_sl = P_ex + P_req_sl;  %Power required @ SL [hp]
    [P_engine_sl , i_climb] = min(P_av_sl); %Get max value and indice
    P_climb = P_engine_sl; %Power the engine needs to produce @ SL [hp]
    v_climb = v_sl(i_climb); %Velocity of climb [fps]
    
    %Calculate what the minimum power needed is
    if(max(P_req_sl) > max(P_req_10k) && max(P_req_sl) > P_climb)
        P_needed = max(P_req_sl)/eta_p_loit;
    elseif(max(P_req_10k) > max(P_req_sl) && max(P_req_10k) > P_climb)
            P_needed = max(P_req_10k)/eta_p_loit;
    else
        P_needed = P_climb/eta_p_loit;
    end
    
    %Get the index of the engine that we can use
    index = getEngineWeight(P_needed, engines);
    
    %Check to make sure we could get a good engine weight
    if(index ~= 0)
        W_engine = engines(index,2); %Weight of the engine [lbs]
        P_engine = engines(index, 1); %Engine power [hp]
    
    %Additional weight values
    Fuel_vol = W_fuel/6.01;  %Volume of fuel [gal]
    W_eng_tot = 1.16*W_engine; %Total Propulsion sys weight [lbs]
    W_nacelle = .175*engines(index,1);  %Nacelle Weight [lbs]
    W_contsys = controls(size(controls));  %Control sys weight [lbs]
    W_fuelsys = 1.25*(114/454);  %Fuel System weight (1000 ml tank) [lbs] 
    
    W_tot = W_payload(1) + W_fuel + W_wing + W_fuse + W_htail + W_nacelle +...
        W_vtail + W_eng_tot + W_fuelsys + W_contsys(1);  %Total aircraft weight [lbs]
    
    %Check for convergence
    if(abs(W_i - W_tot) < W_thresh)
       if (W_tot <= W_max) %Check to make sure its less than max weight
           Validity.Weight = true;
       else
           Validity.Weight = false;
       end % if W_tot
       break; %Break out of loop
    else
        W_i = W_tot; %Update weight
        k = k + 1;
    end
        k = k + 1; 
    end %if index

end %while

%-----------------------------Airfoil-------------------------------------%

%Lift curve slopes are from Cl vs. Alpha graphs for 4412
a_w = 1.50/10;  %Wing lift-curve slope [deg^-1]
a_w = a_w*360/2/pi; %Wing lift-curve slope [rad^-1]
a_t = 1.50/10; %Tail lift-curve slope [deg^-1]
a_t = a_t*360/2/pi; %Tail lift-curve slope [deg^-1]
alpha_ZL = -4.35; %Zero-lift AoA for NACA 4412 [deg]
alpha_ZL = alpha_ZL*pi/180; %zero lift AoA for NACA 4412 [rad]
CL_w0=-alpha_ZL*a_w;

cl_NACA1 = 0.4833; %two points on for airfoil cl curve in linear region
cl_NACA2 = 0.5102;
alpha_NACA1 = 0; %two points on airfoil cl curve in linear region, alpha [deg]
alpha_NACA1 = alpha_NACA1*pi/180; %two points on airfoil cl curve in linear region, alpha [rad]
alpha_NACA2 = 0.2500; %two points on airfoil cl curve in linear region, alpha [deg]
alpha_NACA2 = alpha_NACA2*pi/180; %two points on cl curve in linear region, alpha [rad]

Cl_alpha = (cl_NACA2-cl_NACA1)/(alpha_NACA2-alpha_NACA1); %2-D lift-curve slope [1/rad]
Cl_0 = cl_NACA1; %2-d lift-curve slope 

a_stall = 734.5; %Speed of sound @ 10k feet [mph]
a_stall = a_stall*5280/3600; %Speed of sound @ 10k feet [fps]
M_stall = v_stall/a_stall; %Mach number, vstall @10k (mph/mph)
beta_stall = (1-M_stall^2)^0.5; %Correction factor

kk_stall = Cl_alpha/(2*pi); %ratio between 2-d lift curve slope and elliptical lift distribution
CL_alpha = (2*pi*A)/(2+sqrt(((A*beta_stall)/kk_stall)^2+4)); %3-d lift-curve slope for wing ([-]
CL_0_HT = 0; %3-d CL0 for tail [-]
CL_0_tot = Cl_0+(S_ht/S_w)*CL_0_HT; %3-d CL total for wing + tail [-]
epsilon_0 = (2*CL_0_tot)/(pi*A); 
epsilon_alpha = (2*a_w)/(pi*A); % Downwash efficiency loss [-]
CL_alpha_tot = CL_alpha+(S_ht/S_w)*CL_alpha*(1-epsilon_alpha); %3-D lift curve total slope for wing and tail (1/rad)
alpha = (-5:10).*pi./180; %AoA [rad]

CL_tot = CL_0_tot+CL_alpha_tot.*alpha; %3-D lift coefficient for wing and tail [-]
CL_stall = W_i/(.5*rho_10k*v_stall^2*S_w); %CL at Stall condition [-]
CL_loit = (2*W_tot)/(rho_10k*(v_loit^2)*S_w); %CL @ Vloit, 10k ft
CL_cruise = (2*W_tot)/(rho_10k*(v_cruise^2)*S_w);

alpha_stall = (CL_stall-CL_0_tot)/CL_alpha_tot; %AoA @ Vstall, 10k ft [rad]
alpha_loit = (CL_loit-CL_0_tot)/(CL_alpha_tot); %AoA @ Vloit, 10k ft [rad]
alpha_cr = (CL_cruise - CL_0_tot)/CL_alpha_tot; %AoA @ Vcruise, 10k ft [rad]

%-----------------------------CG/NP/SM Calculations-----------------------%

h_acw = .25;  %AC of wing, wrt leading edge of wing, in proportion to chord [-]

theta_f = acos(2*chord_f/chord - 1); %[rad]
tau = 1 - (theta_f - sin(theta_f)) / pi; % Flap effectiveness factor [-]
M_acw = 0; %Moment about the AC, [ft-lbs] -> HOW TO CALCULATE THIS
CM_acw_cr = M_acw/(.5*rho_10k*v_cruise^2*S_w*chord); %Mom. Coeff about AC during cruise [-]
CM_acw_loit = M_acw/(.5*rho_10k*v_loit^2*S_w*chord); %Mom. Coeff about AC during cruise [-]

V_H = l_t*S_ht/(chord*S_w); %Tail volume ratio [-]

%Declare symbols
syms h_cg_sym_cr;
syms h_cg_sym_loit; 

h_n = h_acw + V_H*(a_t/a_w)*(1-epsilon_alpha); %Neutral point [-]

%Solve for centers of gravity, wrt wing leading edge, prop to chord [-]
eq_cr = a_w*((h_cg_sym_cr - h_acw) - V_H*(a_t/a_w)*(1-epsilon_alpha))*alpha_cr...
    + CM_acw_cr + V_H*a_t*i_t; %At cruise
eq_loit = a_w*((h_cg_sym_loit - h_acw) - V_H*(a_t/a_w)*(1-epsilon_alpha))*alpha_loit...
    + CM_acw_loit + V_H*a_t*i_t; %At loiter

h_cg_solution_set_cr = vpa(solve(eq_cr == 0, h_cg_sym_cr)); %Define solution
h_cg_cr = double(h_cg_solution_set_cr(1)); %Solve Eq
h_cg_solution_set_loit = vpa(solve(eq_loit == 0, h_cg_sym_loit)); %Define solution
h_cg_loit = double(h_cg_solution_set_loit(1)); %Solve Eq

static_margin_cr = h_n - h_cg_cr; %Static Margin during cruise [-]
static_margin_loit = h_n - h_cg_loit; %Static Margin during loiter [-]

h_act_cr = l_t/chord + h_cg_cr; %AC of tail, wrt leading edge of wing, in proportion to chord [-]
h_act_loit = l_t/chord + h_cg_loit; %AC of tail, wrt leading edge of wing, in proportion to chord [-]

%Check for stability
%CG must be greater than neutral point
if(h_cg_cr < h_n) 
    Validity.CG_cr = true;
else
    Validity.CG_cr = false;
end

if(h_cg_loit < h_n)
    Validity.CG_loit = true;
else
    Validity.CG_loit = false;
end

%----------------MOMENT COEFFICIENT INDIVIDUAL COMPONENTS-----------------%

eta=1; %ratio of dynamic pressure at tail/dynamic pressure at wing [-]
Cm_0t=eta*V_H*a_t*(epsilon_0-i_t); %zero AoA moment contribution from tail
Cm_alphat=-eta*V_H*a_t*(1-epsilon_alpha); %change in AoA moment contribution from tail [1/rad]

%----------------------Other Stability Calculations-----------------------%

%Moments + Coefficients due to wing about CG [-]
L_w_10k_loit = .5*rho_10k*v_loit^2*CL_loit*S_w; %Lift from wing during loiter [lbs]
L_w_10k_cr = .5*rho_10k*v_cruise^2*CL_cruise*S_w; %Lift from wing during loiter [lbs]
M_cgw_loit = M_acw + L_w_10k_loit*(h_cg_loit*chord - h_acw*chord); %Loiter
M_cgw_cr = M_acw + L_w_10k_cr*(h_cg_cr*chord - h_acw*chord); %Cruise

CM_cgw_loit = M_cgw_loit/(.5*rho_10k*v_loit^2*S_w*chord); %Loiter
CM_cgw_cr = M_cgw_cr/(.5*rho_10k*v_cruise^2*S_w*chord); %Cruise

alpha_t_loit = (1-epsilon_alpha)*alpha_loit - i_t; %Tail Eff. Angle of Attack @ loit [rad]
alpha_t_cr = (1-epsilon_alpha)*alpha_cr - i_t; %Tail Eff. Angle of Attack @ cruise [rad]
CL_t_loit = a_t*alpha_t_loit; %Tail coeff. of lift at loiter [-]
CL_t_cr = a_t*alpha_t_cr; %Tail coeff. of lift at cruise [-]
CM_cgt_loit = V_H*CL_t_loit; % Moment Coeff. due to tail about CG at loiter [-]
CM_cgt_cr = V_H*CL_t_cr; % Moment Coeff. due to tail about CG at cruise [-]

CM_0_loit = CM_acw_loit + V_H*a_t*i_t;
CM_0_cr = CM_acw_cr + V_H*a_t*i_t;

CL_alpha = a_w + a_t*(S_ht/S_w)*(1-epsilon_alpha);
CM_alpha_cr = CL_alpha*(h_cg_cr - h_n);
CM_alpha_loit = CL_alpha*(h_cg_loit - h_n);
CL_0 = -a_t*(S_ht/S_w)*i_t;

CL_del_e = tau*a_t*(S_ht/S_w); 
CM_del_e = -tau*V_H*a_t;

delta_e_loit = -(CM_0_loit*CL_alpha + CM_alpha_loit*CL_loit)/...
    (CL_alpha*CM_del_e - CM_alpha_loit*CL_del_e); %Elevator to trim [rad?]
delta_e_cr = -(CM_0_cr*CL_alpha + CM_alpha_cr*CL_cruise)/...
    (CL_alpha*CM_del_e - CM_alpha_cr*CL_del_e); %Elevator to trim [rad?]
CL_q = 2*eta*V_H*CL_alpha*(1-epsilon_alpha); %lift coefficient due to pitch rate
CM_q = -(l_t/chord)*CL_q; %moment coefficient due to pitch rate

%------------------------------Lift Calculations--------------------------%

%Check Lift at stall
L_tot_stall = .5*rho_10k*v_stall^2*((a_w + a_t*(S_ht/S_w)*...
    (1 - epsilon_alpha))*alpha_stall - a_t*(S_ht/S_w)*i_t); %Total Lift [lbs]

if(L_tot_stall >= W_i) %If more lift than weight
    Validity.Lift = true; %Mark as valid
else
    Validity.Lift = false; %Mark as invalid
end

%---------------------Mission Specs Verification--------------------------%

%TODO: ADD TAKE OFF/CLIMB FUEL CONSUMPTION
Wf_cr_1 = W_i*(1/exp(R_cruise*c_p_cruise...
    /(eta_p_cruise*L_D_cr))); %Fuel after cruise to fire [lbs]
Wf_loit = ((1/Wf_cr_1) + endur*c_p_loit/...
    (eta_p_loit*L32_D_loit*sqrt(2*rho_10k*S_w)))^-2; %Fuel after loiter [lbs]
Wf_cr_2 = Wf_loit*(1/exp(R_cruise*c_p_cruise...
    /(eta_p_cruise*L_D_cr))); %Fuel after cruise from fire [lbs]
%TODO: ADD LANDING FUEL CONSUMPTION

%Check to see if we have enough fuel
if((W_i - Wf_cr_2) < W_fuel)
    Validity.mission = true;
else
    Validity.mission = false;
end

%Check Rate of climb
if((P_engine*550 - D_tot_10k(i_climb)*v_climb) >= RC) %[ft-lbs/s]
    Validity.RC = true;
else
    Validity.RC = false;
end

%Check max speed at 10k feet
if(P_engine*550 > D_tot_10k(100)*v_max_10k) %[ft-lbs/s]
    Validity.max_10k_speed = true;
else
    Validity.max_10k_speed = false;
end

%Check max speed at sl
if(P_engine*550 > D_tot_sl(100)*v_max_sl) %[ft-lbs/s]
    Validity.max_sl_speed = true;
else
    Validity.max_sl_speed = false;
end

%----------------------Check entire design and save-----------------------%

%Check to see if Validity Struct is good
Good_design = true;
fn = fieldnames(Validity);
for j = 1:numel(fn)
    %If false, design is bad
    if(~Validity.(fn{j}))
      Good_design = false;
      break; %Breakout
    end
end %for j = numel

if(Good_design) %If good, save the design in the struct array
    %Increase number
    n_good = n_good + 1;
    
    %Design Parameters
    Good_designs(n_good).weight = W_tot;  %Total weight [lbs]
    Good_designs(n_good).S_w = S_w; %Wing Surface area [ft^2]
    Good_designs(n_good).b_w = b_w;  %Wingspan [ft]
    Good_designs(n_good).A = A;    %Aspect Ratio [-]
    Good_designs(n_good).e = e; %Rectangular wing efficiency [-]
    Good_designs(n_good).lam_1_4 = lam_1_4; %Wing Quarter chord sweep [rad]
    Good_designs(n_good).lam = lam;   %Taper ratio [-]
    Good_designs(n_good).thicc = thicc;  %Maximum thickness ratio (Last 2 digits of NACA) [-]
    Good_designs(n_good).N = N;  %Ultimate load factor [-]
    Good_designs(n_good).L_fuse = L_fuse; %Length of fuselage [ft]
    Good_designs(n_good).Wid_fuse = Wid_fuse;  %Width of fuselage [ft]
    Good_designs(n_good).D_fuse = D_fuse; %Depth of fuselage [ft]
    Good_designs(n_good).S_ht = S_ht; %Horizontal tail surface area [ft^2]  (Might have to calculate this in while loop)
    Good_designs(n_good).l_t = l_t; %Distance from wing 1/4 MAC to tail 1/4 MAC [ft]
    Good_designs(n_good).b_h = b_h; %Horizontal tail span [ft]
    Good_designs(n_good).S_vt = S_vt; %Vertical tail surface area [ft^2]  (Might have to calculate this in while loop)
    Good_designs(n_good).b_v = b_v; %Vertical tail span [ft]
    Good_designs(n_good).eng_ind = index;  %Engine index
    Good_designs(n_good).eng_hp = engines(index,1);  %Engine power [hp]
    Good_designs(n_good).W_S = W_tot/S_w;    %Wing Loading [lbs/ft^2]
    Good_designs(n_good).Preq_W = P_needed/W_tot;  %Power Loading [hp/lb]
    Good_designs(n_good).P_needed = P_needed;  %Power actually require [hp]
    Good_designs(n_good).chord = chord;  %Chord length [ft]
    Good_designs(n_good).i_t = i_t; %Tail Incidence Angle [deg]
    Good_designs(n_good).chord_f = chord_f; %Flap chord Length [ft]
    Good_designs(n_good).C_m = C_m; %Mean aerodynamic chord [ft]

    %Save the weight breakdown as well
    Good_designs(n_good).w_payload = W_payload(1);  %Weight of the payload [lbs]
    Good_designs(n_good).w_fuel = W_fuel; %Weight of the fuel [lbs]
    Good_designs(n_good).w_wing = W_wing; %Weight of the wing [lbs]
    Good_designs(n_good).w_fuselage = W_fuse;  %Weight of the fuselage [lbs]
    Good_designs(n_good).w_hor_tail = W_htail; %Weight of the horizontal tail [lbs]
    Good_designs(n_good).w_nacelle = W_nacelle; %Weight of the nacelle [lbs]
    Good_designs(n_good).w_ver_tail = W_vtail; %Weight of the vertical tail [lbs]
    Good_designs(n_good).w_engine = W_eng_tot; %Total engine weight [lbs]
    Good_designs(n_good).w_fuel_system = W_fuelsys; %Weight of the fuel system [lbs]
    Good_designs(n_good).w_control_system = W_contsys(1); %Weight of the control system [lbs]
    
    %Mission stuff
    Good_designs.(n_good).v_cruise = v_cruise;
    Good_designs.(n_good).v_loit = v_loit;
    Good_designs.(n_good).v_climb = v_climb;
    Good_designs.(n_good).L_D_loit = L_D_loit;
    Good_designs.(n_good).L_D_cr= L_D_cr;
    
    %Airfoil Stuff
    Good_designs(n_good).CL_tot = CL_tot; %3-D lift coefficient for wing and tail [-]
    Good_designs(n_good).CL_stall = CL_stall; %CL at Stall condition [-]
    Good_designs(n_good).CL_loit = CL_loit; %CL @ Vloit, 10k ft
    Good_designs(n_good).CL_cruise = CL_cruise;
    Good_designs(n_good).alpha_stall = alpha_stall; %AoA @ Vstall, 10k ft [rad]
    Good_designs(n_good).alpha_loit = alpha_loit; %AoA @ Vloit, 10k ft [rad]
    Good_designs(n_good).alpha_cr = alpha_cr; %AoA @ Vcruise, 10k ft [rad]
    
    %CG Stuff
    Good_designs(n_good).tau = tau; % Flap effectiveness factor [-]
    Good_designs(n_good).M_acw = M_acw; %Moment about the AC, [ft-lbs] -> HOW TO CALCULATE THIS
    Good_designs(n_good).CM_acw_cr = CM_acw_cr; %Mom. Coeff about AC during cruise [-]
    Good_designs(n_good).CM_acw_loit = CM_acw_loit; %Mom. Coeff about AC during cruise [-]
    Good_designs(n_good).V_H = V_H; %Tail volume ratio [-]
    Good_designs(n_good).static_margin_cr = static_margin_cr; %Static Margin during cruise [-]
    Good_designs(n_good).static_margin_loit = static_margin_loit; %Static Margin during loiter [-]
    Good_designs(n_good).h_act_cr = h_act_cr; %AC of tail, wrt leading edge of wing, in proportion to chord [-]
    Good_designs(n_good).h_act_loit = h_act_loit; %AC of tail, wrt leading edge of wing, in proportion to chord [-]
    
    %Stability
    Good_designs(n_good).Cm_0t = Cm_0t; %zero AoA moment contribution from tail
    Good_designs(n_good).Cm_alphat = Cm_alphat; %change in AoA moment contribution from tail [1/rad]
    Good_designs(n_good).L_w_10k_loit = L_w_10k_loit; %Lift from wing during loiter [lbs]
    Good_designs(n_good).L_w_10k_cr = L_w_10k_cr; %Lift from wing during loiter [lbs]
    Good_designs(n_good).M_cgw_loit = M_cgw_loit; %Loiter
    Good_designs(n_good).M_cgw_cr = M_cgw_cr; %Cruise
    Good_designs(n_good).CM_cgw_loit = CM_cgw_loit; %Loiter
    Good_designs(n_good).CM_cgw_cr = CM_cgw_cr; %Cruise
    Good_designs(n_good).alpha_t_loit = alpha_t_loit; %Tail Eff. Angle of Attack @ loit [rad]
    Good_designs(n_good).alpha_t_cr = alpha_t_cr; %Tail Eff. Angle of Attack @ cruise [rad]
    Good_designs(n_good).CL_t_loit = CL_t_loit; %Tail coeff. of lift at loiter [-]
    Good_designs(n_good).CL_t_cr = CL_t_cr; %Tail coeff. of lift at cruise [-]
    Good_designs(n_good).CM_cgt_loit = CM_cgt_loit; % Moment Coeff. due to tail about CG at loiter [-]
    Good_designs(n_good).CM_cgt_cr = CM_cgt_cr; % Moment Coeff. due to tail about CG at cruise [-]
    Good_designs(n_good).CM_0_loit = CM_0_loit;
    Good_designs(n_good).CM_0_cr = CM_0_cr;
    Good_designs(n_good).CL_alpha = CL_alpha;
    Good_designs(n_good).CM_alpha_cr = CM_alpha_cr;
    Good_designs(n_good).CM_alpha_loit = CM_alpha_loit;
    Good_designs(n_good).CL_0 = CL_0;
    Good_designs(n_good).CL_del_e = CL_del_e; 
    Good_designs(n_good).CM_del_e = CM_del_e;
    Good_designs(n_good).delta_e_loit = delta_e_loit; %Elevator to trim [rad?]
    Good_designs(n_good).delta_e_cr = delta_e_cr; %Elevator to trim [rad?]
    Good_designs(n_good).CL_q = CL_q; %lift coefficient due to pitch rate
    Good_designs(n_good).CM_q = CM_q; %moment coefficient due to pitch rate

else
    %Increase number
    n_bad = n_bad + 1;
    
    %Design Parameters
    Bad_designs(n_bad).weight = W_tot;  %Total weight [lbs]
    Bad_designs(n_bad).S_w = S_w; %Wing Surface area [ft^2]
    Bad_designs(n_bad).b_w = b_w;  %Wingspan [ft]
    Bad_designs(n_bad).A = A;    %Aspect Ratio [-]
    Bad_designs(n_bad).e = e; %Rectangular wing efficiency [-]
    Bad_designs(n_bad).lam_1_4 = lam_1_4; %Wing Quarter chord sweep [rad]
    Bad_designs(n_bad).lam = lam;   %Taper ratio [-]
    Bad_designs(n_bad).thicc = thicc;  %Maximum thickness ratio (Last 2 digits of NACA) [-]
    Bad_designs(n_bad).N = N;  %Ultimate load factor [-]
    Bad_designs(n_bad).L_fuse = L_fuse; %Length of fuselage [ft]
    Bad_designs(n_bad).Wid_fuse = Wid_fuse;  %Width of fuselage [ft]
    Bad_designs(n_bad).D_fuse = D_fuse; %Depth of fuselage [ft]
    Bad_designs(n_bad).S_ht = S_ht; %Horizontal tail surface area [ft^2]  (Might have to calculate this in while loop)
    Bad_designs(n_bad).l_t = l_t; %Distance from wing 1/4 MAC to tail 1/4 MAC [ft]
    Bad_designs(n_bad).b_h = b_h; %Horizontal tail span [ft]
    Bad_designs(n_bad).S_vt = S_vt; %Vertical tail surface area [ft^2]  (Might have to calculate this in while loop)
    Bad_designs(n_bad).b_v = b_v; %Vertical tail span [ft]
    Bad_designs(n_bad).eng_ind = index;  %Engine index
    Bad_designs(n_bad).eng_hp = engines(index,1);  %Engine power [hp]
    Bad_designs(n_bad).W_S = W_tot/S_w;    %Wing Loading [lbs/ft^2]
    Bad_designs(n_bad).Preq_W = P_needed/W_tot;  %Power Loading [hp/lb]
    Bad_designs(n_bad).P_needed = P_needed;  %Power actually require [hp]
    Bad_designs(n_bad).chord = chord;  %Chord length [ft]
    Bad_designs(n_bad).i_t = i_t; %Tail Incidence Angle [deg]
    Bad_designs(n_bad).chord_f = chord_f; %Flap chord Length [ft]
    Bad_designs(n_bad).C_m = C_m; %Mean aerodynamic chord [ft]

    %Save the weight breakdown as well
    Bad_designs(n_bad).w_payload = W_payload(1);  %Weight of the payload [lbs]
    Bad_designs(n_bad).w_fuel = W_fuel; %Weight of the fuel [lbs]
    Bad_designs(n_bad).w_wing = W_wing; %Weight of the wing [lbs]
    Bad_designs(n_bad).w_fuselage = W_fuse;  %Weight of the fuselage [lbs]
    Bad_designs(n_bad).w_hor_tail = W_htail; %Weight of the horizontal tail [lbs]
    Bad_designs(n_bad).w_nacelle = W_nacelle; %Weight of the nacelle [lbs]
    Bad_designs(n_bad).w_ver_tail = W_vtail; %Weight of the vertical tail [lbs]
    Bad_designs(n_bad).w_engine = W_eng_tot; %Total engine weight [lbs]
    Bad_designs(n_bad).w_fuel_system = W_fuelsys; %Weight of the fuel system [lbs]
    Bad_designs(n_bad).w_control_system = W_contsys(1); %Weight of the control system [lbs]
    
    %Airfoil Stuff
    Bad_designs(n_bad).CL_tot = CL_tot; %3-D lift coefficient for wing and tail [-]
    Bad_designs(n_bad).CL_stall = CL_stall; %CL at Stall condition [-]
    Bad_designs(n_bad).CL_loit = CL_loit; %CL @ Vloit, 10k ft
    Bad_designs(n_bad).CL_cruise = CL_cruise;
    Bad_designs(n_bad).alpha_stall = alpha_stall; %AoA @ Vstall, 10k ft [rad]
    Bad_designs(n_bad).alpha_loit = alpha_loit; %AoA @ Vloit, 10k ft [rad]
    Bad_designs(n_bad).alpha_cr = alpha_cr; %AoA @ Vcruise, 10k ft [rad]
    
    %Mission stuff
    Bad_designs.(n_bad).v_cruise = v_cruise;
    Bad_designs.(n_bad).v_loit = v_loit;
    Bad_designs.(n_bad).v_climb = v_climb;
    Bad_designs.(n_bad).L_D_loit = L_D_loit;
    Bad_designs.(n_bad).L_D_cr= L_D_cr;
    
    %CG Stuff
    Bad_designs(n_bad).tau = tau; % Flap effectiveness factor [-]
    Bad_designs(n_bad).M_acw = M_acw; %Moment about the AC, [ft-lbs] -> HOW TO CALCULATE THIS
    Bad_designs(n_bad).CM_acw_cr = CM_acw_cr; %Mom. Coeff about AC during cruise [-]
    Bad_designs(n_bad).CM_acw_loit = CM_acw_loit; %Mom. Coeff about AC during cruise [-]
    Bad_designs(n_bad).V_H = V_H; %Tail volume ratio [-]
    Bad_designs(n_bad).static_margin_cr = static_margin_cr; %Static Margin during cruise [-]
    Bad_designs(n_bad).static_margin_loit = static_margin_loit; %Static Margin during loiter [-]
    Bad_designs(n_bad).h_act_cr = h_act_cr; %AC of tail, wrt leading edge of wing, in proportion to chord [-]
    Bad_designs(n_bad).h_act_loit = h_act_loit; %AC of tail, wrt leading edge of wing, in proportion to chord [-]
    
    %Stability
    Bad_designs(n_bad).Cm_0t = Cm_0t; %zero AoA moment contribution from tail
    Bad_designs(n_bad).Cm_alphat = Cm_alphat; %change in AoA moment contribution from tail [1/rad]
    Bad_designs(n_bad).L_w_10k_loit = L_w_10k_loit; %Lift from wing during loiter [lbs]
    Bad_designs(n_bad).L_w_10k_cr = L_w_10k_cr; %Lift from wing during loiter [lbs]
    Bad_designs(n_bad).M_cgw_loit = M_cgw_loit; %Loiter
    Bad_designs(n_bad).M_cgw_cr = M_cgw_cr; %Cruise
    Bad_designs(n_bad).CM_cgw_loit = CM_cgw_loit; %Loiter
    Bad_designs(n_bad).CM_cgw_cr = CM_cgw_cr; %Cruise
    Bad_designs(n_bad).alpha_t_loit = alpha_t_loit; %Tail Eff. Angle of Attack @ loit [rad]
    Bad_designs(n_bad).alpha_t_cr = alpha_t_cr; %Tail Eff. Angle of Attack @ cruise [rad]
    Bad_designs(n_bad).CL_t_loit = CL_t_loit; %Tail coeff. of lift at loiter [-]
    Bad_designs(n_bad).CL_t_cr = CL_t_cr; %Tail coeff. of lift at cruise [-]
    Bad_designs(n_bad).CM_cgt_loit = CM_cgt_loit; % Moment Coeff. due to tail about CG at loiter [-]
    Bad_designs(n_bad).CM_cgt_cr = CM_cgt_cr; % Moment Coeff. due to tail about CG at cruise [-]
    Bad_designs(n_bad).CM_0_loit = CM_0_loit;
    Bad_designs(n_bad).CM_0_cr = CM_0_cr;
    Bad_designs(n_bad).CL_alpha = CL_alpha;
    Bad_designs(n_bad).CM_alpha_cr = CM_alpha_cr;
    Bad_designs(n_bad).CM_alpha_loit = CM_alpha_loit;
    Bad_designs(n_bad).CL_0 = CL_0;
    Bad_designs(n_bad).CL_del_e = CL_del_e; 
    Bad_designs(n_bad).CM_del_e = CM_del_e;
    Bad_designs(n_bad).delta_e_loit = delta_e_loit; %Elevator to trim [rad?]
    Bad_designs(n_bad).delta_e_cr = delta_e_cr; %Elevator to trim [rad?]
    Bad_designs(n_bad).CL_q = CL_q; %lift coefficient due to pitch rate
    Bad_designs(n_bad).CM_q = CM_q; %moment coefficient due to pitch rate
    
    %Validity
    Bad_designs(n_bad).Valid_Weight = Validity.Weight;
    Bad_designs(n_bad).Valid_CG_cr = Validity.CG_cr;
    Bad_designs(n_bad).Valid_CG_loit = Validity.CG_loit;
    Bad_designs(n_bad).Valid_lift = Validity.Lift;
    Bad_designs(n_bad).Valid_mission = Validity.mission;
    Bad_designs(n_bad).Valid_RC = Validity.RC;
    Bad_designs(n_bad).Valid_max_10k_speed = Validity.max_10k_speed;
    Bad_designs(n_bad).Valid_max_sl_speed = Validity.max_sl_speed;
end

end %for n = 1

%Save to spreadsheet
fprintf('Number of Good Designs Found: %d\n', n_good);
fprintf('Number of Bad Designs Found: %d\n', n_bad);
fprintf('Writing Designs to Spreadsheet... ');

if(n_good)
    xlswrite('Good_Designs.xlsx',A);
    writetable(struct2table(Good_designs),'Good_Designs.xlsx');
end
if(n_bad)
    xlswrite('Bad_Designs.xlsx',A);
    writetable(struct2table(Bad_designs),'Bad_Designs.xlsx');
end
fprintf('Done!\n');

%-------------------------FUSELAGE SECTIONS-------------------------------%

%perimeters 1-6 represent mid-point perimeter of sectioned fuselage starting from nose
perimeter_1=18.89; % mid-section perimeters [in]
perimeter_2=27.87;
perimeter_5=25.15;
perimeter_6=38.72-10.31*1.08;
wf_1=perimeter_1/(pi); %estimation of average width of each section [in]
wf_2=perimeter_2/pi;
wf_5=25.15/pi;
wf_6=perimeter_6/pi;
wf_6p=wf_6+0.5*10.31*1.08;
dx1=4.16; %length of each section, 1-6 (NEEDS TO BE UPDATED) [in]
dx2=4;
dx3=4;
dx4=4;
dx5=4;
dx6=4;

xi5=2; %distance from fuselage mid-section 5 to wing T.E. (NEEDS TO BE UPDATED) [in]
xi6=6; %distance from fuselage mid-section 6 to wing T.E. (NEEDS TO BE UPDATED) [in]
eps_u1=1.3; %graphically determined upwash for sections 1&2 [1/rad]
eps_u2=1.5; %graphically determined upwash for sections 1&2 [1/rad]
eps_u3=0; %sections 3&4 are approximated to have no upwash or downwash [1/rad]
eps_u4=0;
eps_u5=(xi5/11.21)*(1-epsilon_alpha); %assumed linear progression in downwash from T.E to tail; estimation of downwash based 
                                      %on linear model
eps_u6=(xi6/11.21)*(1-epsilon_alpha);

Cm_alphaf=1/(36.5*S_w*144*11.21)*((wf_1^2)*eps_u1*dx1+(wf_2^2)...
    *eps_u2*dx2+(wf_5^2)*eps_u5*dx5+(wf_6^6)*eps_u6*dx6); %estimation of contribution of fuselage to moment coeff from change in AoA [1/rad]
k2_k1=0.6; %graphically determined coefficient to determine zero AoA fuselage contribution to moment
Cm_0f=((k2_k1)/(36.5*S_w*144*11.21))*((wf_1^2)*dx1+(wf_2^2)...
    *dx2+(wf_3^2)*dx3+(wf_4^2)*dx4+(wf_5^2)*dx5+(wf_6^2)*wf_6)*alpha_ZL; %estimation of contribution of fuselage to moment coeff at zero AoA [1/rad]
    
%TODO
%How do we update the TSFC -> What is it initially and how does it
% change with velocity?
%Why are we having issues with total lift?
%Add stability calculations
%    - Longitudinal Control
%    - Directional Control
%More checks -> How do we show its stable?
%Takeoff, climb, landing fuel consumption?
%Finish labeling everything and cleaning up code
%TRIPLE CHECK LITERALLY EVERYTHING
