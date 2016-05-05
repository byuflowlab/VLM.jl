type CPdata
    chord::Array{Float64, 1}
    twist::Array{Float64, 1}
    tc::Array{Float64, 1}
    x::Array{Float64, 1}
    y::Array{Float64, 1}
    z::Array{Float64, 1}
    dihedral::Array{Float64, 1}
    sweep::Array{Float64, 1}
    ds::Array{Float64, 1}
end

type position
    x::Array{Float64, 1}
    y::Array{Float64, 1}
    z::Array{Float64, 1}
end

# lift influence coefficients
function getLIC(CP::CPdata, rho::Float64, Vinf::Float64)
    LIC = 2*rho*Vinf*cos(CP.dihedral).*CP.ds
end

#=
-----------------------------------
Pitching moment coefficients about (x) c.g. location

Author: S. Andrew Ning
Updates: 1/30/09 - removed dependence on QC since this is known
-------------------------------------
=#
function getMIC(CP::CPdata, rho::Float64, Vinf::Float64, xcg::Float64)

    xQC = CP.x - 0.5*CP.chord # quarter chord locations

    MIC = -(xQC - xcg)*2*rho*Vinf.*cos(CP.dihedral).*CP.ds

end


#=
------------------------------------------------
Induced drag influence coefficients with a Trefftz plane calculation
Di = gamma'*DIC*gamma


Author: S. Andrew Ning

Updated feb. 13 2008
1 is control points, 2 is vorticies.  If you leave out last two
arguments the control points and vorticies are on one wing.  Include them
if you need effect of wing on tail for example.
-------------------------------------------------
=#

function getDIC(yFF::Array{Float64, 1}, zFF::Array{Float64, 1}, rho::Float64)
    getDIC(yFF, zFF, rho, yFF, zFF)
end

function getDIC(yFF::Array{Float64, 1}, zFF::Array{Float64, 1}, rho::Float64, yFF2::Array{Float64, 1}, zFF2::Array{Float64, 1})

    n = length(yFF)-1
    n2 = length(yFF2)-1

     # ------------ define useful variables ------------------
    yc = 0.5*(yFF[2:n+1] + yFF[1:n])   # center of panels
    zc = 0.5*(zFF[2:n+1] + zFF[1:n])
    ny = zFF[2:n+1] - zFF[1:n]
    nz = yFF[2:n+1] - yFF[1:n]
     # ----------------------------------------------------

    DIC = zeros(n,n2)
     #------- normal wash calculation ----------------
    for i = 1:n
        for j = 1:n2
            ry = yFF2[j] - yc[i]
            rz = zFF2[j] - zc[i]
            r2 = ry^2 + rz^2
            DIC[i, j] = -rho/(2*pi*r2)*(rz*ny[i]+ry*nz[i])

             # add other side of panel
            ry = yFF2[j+1] - yc[i]
            rz = zFF2[j+1] - zc[i]
            r2 = ry^2 + rz^2
            DIC[i, j] += rho(2*pi*r2)*(rz*ny[i]+ry*nz[i])
        end
    end

    yFF2 = -yFF2 # add left side

    for i = 1:n
        for j = 1:n2
            ry = yFF2[j] - yc[i]
            rz = zFF2[j] - zc[i]
            r2 = ry^2 + rz^2
            DIC[i,j] += rho/(2*pi*r2)*(rz*ny[i]+ry*nz[i])

            # add other side of panel
            ry = yFF2[j+1] - yc[i]
            rz = zFF2[j+1] - zc[i]
            r2 = ry^2 + rz^2
            DIC[i,j] -= rho/(2*pi*r2)*(rz*ny[i]+ry*nz[i])
        end
    end

    return DIC
end



#=
---------------------
assumes a parabolic variation in viscous drag with section lift coefficient
Dp = D0 + D1*gamma + D2*gamma.^2

Author: S. Andrew Ning
-----------------------
=#

function getViscousDrag(cd1::Float64, cd2::Float64, CP::CPdata, rho::Float64, Vinf::Float64)

  D1 = cd1*rho*Vinf*CP.ds
  D2 = cd2*2*rho./CP.chord.*CP.ds

  return D1, D2
end


#=
----------------------------------------
 Calculates velocity induced by vortex (with unit vorticity)
 starting at rA ending at rB at control point rC. (see Bertin/Smith)

 Author: S. Andrew Ning
------------------------------------------
=#

function vortex(xA::Array{Float64, 1}, yA::Array{Float64, 1}, zA::Array{Float64, 1},
        xB::Array{Float64, 1}, yB::Array{Float64, 1}, zB::Array{Float64, 1},
        xC::Array{Float64, 1}, yC::Array{Float64, 1}, zC::Array{Float64, 1})

    m = length(yC)
    n = length(yA)
    v = zeros(m, n)
    w = zeros(m, n)

    for i = 1:m
        for j = 1:n
            # define repeatedly used values
            x1 = xC[i] - xA[j]
            x2 = xC[i] - xB[j]
            x21 = xB[j] - xA[j]
            y1 = yC[i] - yA[j]
            y2 = yC[i] - yB[j]
            y21 = yB[j] - yA[j]
            z1 = zC[i] - zA[j]
            z2 = zC[i] - zB[j]
            z21 = zB[j] - zA[j]

            denom1 = (y1*z2-y2*z1)^2 + (x1*z2-x2*z1)^2 + (x1*y2-x2*y1)^2
            # i1 = y1*z2 - y2*z1
            j1 = -x1*z2 + x2*z1
            k1 = x1*y2 - x2*y1
            frac1_1 = (x21*x1 + y21*y1 + z21*z1)/sqrt(x1^2 + y1^2 + z1^2)
            frac1_2 = (x21*x2 + y21*y2 + z21*z2)/sqrt(x2^2 + y2^2 + z2^2)
            frac1 = frac1_1 - frac1_2
            # u[i, j] = 1.0/(4*pi)*i1/denom1*frac1
            v[i, j] = 1.0/(4*pi)*j1/denom1*frac1
            w[i, j] = 1.0/(4*pi)*k1/denom1*frac1
        end
    end

    return v, w
end


#=
------------------------------------------------
This function calculates the induced velocies at control points
xCP,yCP,zCP from the vorticies which are bound at the quarter chord,
follow the wing to the trailing edge, and leave the wing parallel to the
freestream (drag-free wake).  All values are computed for unit vorticity

Author: Andrew Ning
------------------------------------------------
=#
function velocity3d(QC::position, TE::position, CP::CPdata)

    # first calculate induced velocities from vorticies on right side of wing.
    m = length(CP.y)
    n = length(QC.y)-1

    # u = zeros(m, n)
    v = zeros(m, n)
    w = zeros(m, n)

    # Induced velocities due to bound vortex (BC)
    dv, dw = vortex(QC.x[1:n], QC.y[1:n], QC.z[1:n], QC.x[2:n+1], QC.y[2:n+1], QC.z[2:n+1],
        CP.x, CP.y, CP.z)
    # u += du
    v += dv
    w += dw

    # Induced velocities due to AB - left vortex bound to wing
    dv, dw = vortex(TE.x[1:n], TE.y[1:n], TE.z[1:n], QC.x[1:n], QC.y[1:n], QC.z[1:n],
        CP.x, CP.y, CP.z)
    # u += du
    v += dv
    w += dw

    # Induced velocities due to CD - right vortex bound to wing
    dv, dw = vortex(QC.x[2:n+1], QC.y[2:n+1], QC.z[2:n+1], TE.x[2:n+1], TE.y[2:n+1], TE.z[2:n+1],
        CP.x, CP.y, CP.z)
    # u += du
    v += dv
    w += dw

    # Induced velocities due to trailing vortex from A
    l = 1e9  # some large number to represent infinity
    # xINF = TE.x + l*cos(alpha)*ones(size(TE.x))
    # yINF = TE.y
    # zINF = TE.z + l*sin(alpha)*ones(size(TE.z))
    xINF = TE.x + l
    yINF = TE.y
    zINF = TE.z

    dv, dw = vortex(xINF[1:n], yINF[1:n], zINF[1:n], TE.x[1:n], TE.y[1:n], TE.z[1:n],
        CP.x, CP.y, CP.z)
    # u += du
    v += dv
    w += dw

    # Induced velocities due to trailing vortex from D
    dv, dw = vortex(TE.x[2:n+1], TE.y[2:n+1], TE.z[2:n+1], xINF[2:n+1], yINF[2:n+1], zINF[2:n+1],
        CP.x, CP.y, CP.z)
    # u += du
    v += dv
    w += dw

    # ---------- Now repeat with contribution from left side of the wing -----
    # y switched signs (except control points of course)
    # QCy = -QC.y
    # TEy = -TE.y
    # yINF = -yINF
    # Also all induced velocities have opposite sign because vorticies travel
    # in opposite direction.

    # Induced velocities due to bound vortex (BC)
    dv, dw = vortex(QC.x[1:n], -QC.y[1:n], QC.z[1:n], QC.x[2:n+1], -QC.y[2:n+1], QC.z[2:n+1],
        CP.x, CP.y, CP.z)
    # u -= du
    v -= dv
    w -= dw

    # Induced velocities due to AB - left vortex bound to wing
    dv, dw = vortex(TE.x[1:n], -TE.y[1:n], TE.z[1:n], QC.x[1:n], -QC.y[1:n], QC.z[1:n],
        CP.x, CP.y, CP.z)
    # u -= du
    v -= dv
    w -= dw

    # Induced velocities due to CD - right vortex bound to wing
    dv, dw = vortex(QC.x[2:n+1], -QC.y[2:n+1], QC.z[2:n+1], TE.x[2:n+1], -TE.y[2:n+1], TE.z[2:n+1],
        CP.x, CP.y, CP.z)
    # u -= du
    v -= dv
    w -= dw

    # Induced velocities due to trailing vortex from A

    dv, dw = vortex(xINF[1:n], -yINF[1:n], zINF[1:n], TE.x[1:n], -TE.y[1:n], TE.z[1:n],
        CP.x, CP.y, CP.z)
    # u -= du
    v -= dv
    w -= dw

    # Induced velocities due to trailing vortex from D
    dv, dw = vortex(TE.x[2:n+1], -TE.y[2:n+1], TE.z[2:n+1], xINF[2:n+1], -yINF[2:n+1], zINF[2:n+1],
        CP.x, CP.y, CP.z)
    # u -= du
    v -= dv
    w -= dw

    return v, w
end



#=
------------------------------------
Aerodynamic influence coefficients
Vn = AIC*gamma

Author: S. Andrew Ning
Updates: summer 08 - simplified so that twist/camber are only applied in boundary conditions
                     consistent with assumptions of VLM.
--------------------------------------
=#

function getAIC(QC::position, TE::position, CP::CPdata)

    v, w =  velocity3d(QC, TE, CP)

    m = length(CP.y)
    n = length(QC.y)-1

    AIC = zeros(m, n)

    for j = 1:n
        AIC[:, j] = -v[:, j].*sin(CP.dihedral) + w[:, j].*cos(CP.dihedral)
    end

    return AIC
end



#=
-------------------------------------------------
this function computes integrated bending moment over thickness and the
bending moment distribution
W = WIC*gamma;
bending moment distribution = BMM*gamma

Author: S. Andrew Ning
Updates: 1/23/09 - corrected integration along spar and vectorized for speed
         1/30/09 - allows for thickness distribution
---------------------------------------------------
=#


function getWIC(CP::CPdata, rho::Float64, Vinf::Float64)

    x = CP.x - 0.5*CP.chord
    y = CP.y
    z = CP.z

    # rename for convenience
    N = length(y)
    phi = CP.dihedral
    Lambda = CP.sweep
    chord = CP.chord
    tc = CP.tc
    ds = CP.ds

    R = zeros(N, N)

    for i = 1:N
        for j = i+1:N
            cij = cos(CP.dihedral[j])*cos(CP.dihedral[i]) + sin(CP.dihedral[j])*sin(CP.dihedral[i])
            R[i, j] = (x[j] - x[i])*cij*sin(CP.sweep[i]) +
                     (y[j] - y[i])*cos(CP.dihedral[j])*cos(CP.sweep[i]) +
                     (z[j] - z[i])*sin(CP.dihedral[j])*cos(CP.sweep[i])

            # if j <= i, R(i,j) = 0
        end
    end


    # integrate along structural span
    ds_str = CP.ds./cos(CP.sweep)

    BMM = rho*Vinf*R.*repmat(ds, N, 1)  #(ones(N, 1)*ds)
    WIC = 2*(ds_str./(tc.*chord))*BMM

    return WIC, BMM
end

# TODO: haven't tested which is faster in Julia

# # compute R matrix
# PhiM = ((cos(phi)*cos(phi)') + (sin(phi)*sin(phi)'))
# Rx = (sin(Lambda)*x' - (x.*sin(Lambda))*ones(1,N)).*PhiM
# Ry = cos(Lambda)*(y.*cos(phi))' - (y.*cos(Lambda))*cos(phi)'
# Rz = cos(Lambda)*(z.*sin(phi))' - (z.*cos(Lambda))*sin(phi)'
# R = Rx + Ry + Rz
# R = R - tril(R) # R(i,j) = 0 for j <= i


# % below version is exactly the same (slower since its in loops, but left
# % here since it's easier to read then vectorized version above)
#
# % R = zeros(N);
#
# % for i = 1:N
# %     for j = 1:N
# %         cij = cos(CP.dihedral(j))*cos(CP.dihedral(i)) + sin(CP.dihedral(j))*sin(CP.dihedral(i));
# %         R(i,j) = (x(j) - x(i))*cij*sin(CP.sweep(i)) + ...
# %                  (y(j) - y(i))*cos(CP.dihedral(j))*cos(CP.sweep(i)) + ...
# %                  (z(j) - z(i))*sin(CP.dihedral(j))*cos(CP.sweep(i));
# %         if j <= i
# %             R(i,j) = 0;
# %         end
# %     end
# % end

# % ds_str = CP.ds./cos(CP.sweep);
#
# % WIC = zeros(1,N);
# %
# % for j = 1:N
# %     WIC(j) = 2*rho*U/tc*CP.ds(j).*ds_str./CP.chord*R(:,j);
# % end

#=
-----------------------------------------------------
This function computes angle of attack necessary to match a specified
lift

Author: S. Andrew Ning
Updates: 1/28/09 - created
         9/2/09 - changed the way alpha was computed - seems more robust
                 to larger angles of attack by using arcsin rather than arccos
---------------------------------------------------
=#

function getAlpha(Ltarget::Float64, CP::CPdata, LIC::Array{Float64, 1}, AIC::Array{Float64, 2}, Vinf::Float64)

    # solve quadratic equation for alpha
    qq = LIC/AIC
    a = -U*qq*sin(CP.twist)'
    b = -U*qq*(cos(CP.twist).*cos(CP.dihedral))'
    c = Ltarget
    # alpha = acos((a*c + b*sqrt(a^2+b^2-c^2))/(a^2+b^2));
    alpha = asin(c/b - a/b*(a*c + b*sqrt(a^2+b^2-c^2))/(a^2 + b^2))

    return alpha
end