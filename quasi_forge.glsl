// QuasiForge v2 — Cinematic photorealistic audio-reactive quasicrystal
// Core: Iterative sum-of-plane-waves (classic from mainisusuallyafunction 2011)
// New in v2: Unreal Engine 5-style cinematic photorealism layer
//   - Background image/video integration (iChannel1) with dynamic pixel-driven pattern parallelization
//   - Enhanced lighting: height-field "ray-traced" shading, screen-space-like reflections (bg as env), iridescence, volumetric depth/fog
//   - Doppler shift on animation phase and subtle color temperature
//   - All previous features preserved + expanded manual control
//
// Shadertoy: iChannel0 = audio spectrum, iChannel1 = background image or video loop (optional but recommended for cinematic look)
// Synesthesia Visualizer ready: map audio FFT to Channel0, optional media to Channel1. See README for adaptation notes.
//
// Controls: iMouse.x/y for primary params + edit PARAM_* constants as precise sliders.

#define PI 3.141592653589793
#define N 7

// ==================== MANUAL PARAMETERS (precise "sliders") ====================
const float PARAM_BASE_SCALE      = 7.2;
const float PARAM_TIME_RATE       = 1.0;     // Overall twist/warp speed
const float PARAM_DISPERSION      = 0.032;
const float PARAM_AUDIO_SENS      = 1.0;
const float PARAM_COLOR_HUE_SHIFT = 0.0;
const float PARAM_INVERT          = 0.0;
const float PARAM_OCTAVES         = 1.4;
const float PARAM_EXTRUSION       = 0.65;
const float PARAM_MIRROR_MODE     = 0.0;

// New cinematic params
const float PARAM_BG_MIX          = 0.45;    // Blend between procedural and background (0=full procedural, 1=full bg)
const float PARAM_REFLECTION      = 0.35;    // Strength of reflective / env sampling from background
const float PARAM_VOLUMETRIC      = 0.25;    // Volumetric depth / fog density
const float PARAM_DOPPLER         = 0.8;     // Doppler shift intensity on phase and color temp

// ==================== AUDIO MAPPING ====================
// bass  -> scale breathing, Rayleigh, seed direction, volumetric density
// mids  -> phase diversity, hue, iridescence, octave weight, local bg influence strength
// highs -> animation rate, jitter, dispersion dynamics, Doppler factor, reflection sparkle
// Sensitivity applied globally. Background pixels further modulate local phases/amplitudes for "parallelization".

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x*6.0 + vec3(0.,4.,2.),6.)-3.)-1., 0., 1.);
    rgb = rgb*rgb*(3.-2.*rgb);
    return c.z * mix(vec3(1.), rgb, c.y);
}

vec2 applyMirror(vec2 uv, float mode) {
    if (mode > 2.5) uv = abs(uv);
    else if (mode > 1.5) uv.y = abs(uv.y);
    else if (mode > 0.5) uv.x = abs(uv.x);
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Audio + sensitivity
    float sens = PARAM_AUDIO_SENS * (1.0 + iMouse.y * 0.7);
    float bass  = texture(iChannel0, vec2(0.07, 0.25)).x * sens;
    float mids  = texture(iChannel0, vec2(0.27, 0.25)).x * sens;
    float highs = texture(iChannel0, vec2(0.62, 0.25)).x * sens;

    // Scale + manual/audio
    float manualScale = PARAM_BASE_SCALE * (1.0 + iMouse.x * 1.7);
    float scale = manualScale * (1.0 + bass * 0.6);

    // Time + time-rate + Doppler shift (highs + manual Doppler param drive phase velocity and subtle red/blue color temp)
    float dopplerFactor = 1.0 + (highs - 0.5) * PARAM_DOPPLER * 0.6;
    float timeRate = PARAM_TIME_RATE * (1.0 + iMouse.x * 0.85) * dopplerFactor;
    float t = iTime * timeRate;

    // Mirroring
    uv = applyMirror(uv, PARAM_MIRROR_MODE);

    // Background sampling (cinematic base layer)
    // Distort sampling coordinate by interference field for dynamic parallelization
    // (background pixels "emerge" and influence the procedural patterns)
    vec3 bg = vec3(0.05);
    if (iChannel1 != texture(iChannel0, vec2(0.0))) {  // safe check for optional channel
        float bgDistort = 0.0; // will be set after first interference pass
        // First rough interference for distortion (cheap)
        vec2 up0 = vec2(scale * 0.9, 0.0);
        up0 = rot((bass-0.5)*0.1) * up0;
        float roughSum = 0.0;
        mat2 r0 = rot(PI / float(N));
        for (int k=0; k<N; k++) {
            roughSum += cos(dot(uv, up0) + t*0.9 + float(k)*1.1);
            up0 = r0 * up0;
        }
        float roughI = (cos(roughSum*0.5 + 2.0)+1.0)*0.5;
        bgDistort = roughI * 0.025 * (1.0 + mids*0.5);
        vec2 bgUV = uv + vec2(bgDistort * sin(t*0.3), bgDistort * cos(t*0.4));
        bg = texture(iChannel1, bgUV * 0.5 + 0.5).rgb;  // assume bg normalized or adjust
    }

    // Dispersion prep
    float disp = PARAM_DISPERSION * (1.0 + iMouse.y * 1.1 + highs * 0.35);

    // Core wave summation (with per-channel dispersion)
    vec2 up = vec2(scale, 0.0);
    float seedPerturb = (bass - 0.5) * 0.105;
    up = rot(seedPerturb) * up;
    float angleStep = PI / float(N) + (mids - 0.5)*0.017;
    mat2 rmat = rot(angleStep);

    float sumR = 0.0, sumG = 0.0, sumB = 0.0;

    for (int i = 0; i < N; i++) {
        float phaseBase = t + float(i)*(1.12 + mids*1.5) + highs * sin(float(i)*2.35)*0.55 * dopplerFactor;
        float contrib = cos(dot(uv, up) + phaseBase);

        sumR += contrib;
        sumG += contrib;
        sumB += contrib;

        // Dispersion offsets
        float dR = 1.0 + disp;
        float dG = 1.0;
        float dB = 1.0 - disp * 1.15;
        sumR += cos(dot(uv * dR, up) + phaseBase + disp*1.8) * 0.32;
        sumG += cos(dot(uv * dG, up) + phaseBase) * 0.32;
        sumB += cos(dot(uv * dB, up) + phaseBase - disp*2.3) * 0.32;

        up = rmat * up;
    }

    sumR /= float(N)*1.32;
    sumG /= float(N)*1.32;
    sumB /= float(N)*1.32;

    float IR = (cos(sumR*0.51 + 2.03)+1.0)*0.5;
    float IG = (cos(sumG*0.51 + 2.03)+1.0)*0.5;
    float IB = (cos(sumB*0.51 + 2.03)+1.0)*0.5;
    float I = (IR + IG + IB) / 3.0;

    // Background-driven parallelization: add bg luminance influence to local interference and phase
    float bgLum = dot(bg, vec3(0.299, 0.587, 0.114));
    I = mix(I, I * (1.0 + (bgLum-0.5)*0.25), PARAM_BG_MIX * 0.6 + mids*0.2);
    // Also feed bg into phases indirectly via the distortion already applied above

    // Octave layer
    float octaveAmt = PARAM_OCTAVES + mids * 0.55;
    float IOct = I;
    if (octaveAmt > 1.02) {
        float octScale = scale * 2.618;
        vec2 up2 = vec2(octScale, 0.0);
        up2 = rot(seedPerturb * 0.65) * up2;
        float sumOct = 0.0;
        for (int j=0; j<N; j++) {
            float ph2 = t * 1.25 + float(j)*(1.55 + mids*1.15);
            sumOct += cos(dot(uv, up2) + ph2);
            up2 = rmat * up2;
        }
        IOct = (cos(sumOct*0.47 + 1.75)+1.0)*0.5;
        I = mix(I, IOct, (octaveAmt-1.0)*0.55);
        IR = mix(IR, IOct, 0.28);
        IG = mix(IG, IOct, 0.28);
        IB = mix(IB, IOct, 0.28);
    }

    // Cinematic base color + manual spectrum + Doppler color temp shift
    float hueShift = PARAM_COLOR_HUE_SHIFT + iMouse.y * 0.22;
    float dopplerHue = (dopplerFactor - 1.0) * 0.08; // subtle blue/red shift
    float hue = I * 0.36 + t * 0.02 + mids * 0.14 + hueShift + dopplerHue;
    vec3 baseCol = hsv2rgb(vec3(mod(hue,1.0), 0.74, 0.86 + I*0.12));

    // Enhanced iridescence (view-ish dependent via normal proxy + film)
    float film = (sumR+sumG+sumB)*0.58 + uv.x*0.3 + t*0.065;
    vec3 irid;
    irid.r = (cos(film*6.6)+1.0)*0.5;
    irid.g = (cos(film*7.75 + 1.15)+1.0)*0.5;
    irid.b = (cos(film*8.9 + 2.4)+1.0)*0.5;
    float iridMix = 0.58 + highs*0.28 + iMouse.y*0.12;
    vec3 color = mix(baseCol * vec3(IR,IG,IB), irid, iridMix);

    // Rayleigh
    float scatter = 0.48 + bass*0.82;
    vec3 rayleigh = vec3(0.06, 0.18, 0.88) * scatter * (1.0 - I*0.48);
    color += rayleigh;

    // Height-field extrusion + enhanced cinematic lighting (normal + reflection + volumetric)
    float extrude = PARAM_EXTRUSION * (1.0 + mids*0.35);
    if (extrude > 0.01) {
        float eps = 0.75 / scale;
        // Improved proxy normal from interference variation
        float Ix = (cos((sumR + 0.7)*0.51 + 2.0)+1.0)*0.5;
        float Iy = (cos((sumG - 0.55)*0.51 + 2.0)+1.0)*0.5;
        vec3 normal = normalize(vec3((I - Ix)*11.5, (I - Iy)*11.5, 1.0));

        vec3 lightDir = normalize(vec3(0.55, 0.65, 1.1));
        float diff = max(dot(normal, lightDir), 0.12);

        // Reflective term — sample background as environment (cinematic "ray traced" reflection feel)
        vec2 reflectUV = uv + normal.xy * 0.08 * PARAM_REFLECTION;
        vec3 envRefl = texture(iChannel1, reflectUV * 0.5 + 0.5).rgb * PARAM_REFLECTION;
        float reflMask = smoothstep(0.2, 0.85, dot(normal, vec3(0.,0.,1.)));
        color = mix(color, color * 0.6 + envRefl * 1.4, reflMask * PARAM_REFLECTION * 0.7);

        // Diffuse + specular
        color *= mix(1.0, diff, extrude * 0.65);
        float spec = pow(max(dot(reflect(-lightDir, normal), vec3(0.,0.,1.)), 0.0), 16.0);
        color += spec * extrude * 0.32 * vec3(0.85, 0.92, 1.0);

        // Volumetric depth / fog (accumulates with "height" and distance)
        float volDepth = length(uv) * 0.6 + (1.0 - I) * 0.8;
        float fog = exp(-volDepth * PARAM_VOLUMETRIC * (1.0 + bass*0.6));
        color = mix(color * 0.6 + vec3(0.04,0.06,0.12), color, fog);
    }

    // Blend with background for cinematic integration + parallelization
    float bgBlend = PARAM_BG_MIX + mids * 0.15;
    color = mix(color, bg, clamp(bgBlend, 0.0, 0.85));

    // Inversion
    if (PARAM_INVERT > 0.5) color = 1.0 - color;

    // Cinematic polish (tonemap-ish, contrast, vignette)
    color = pow(color, vec3(0.82));
    color = clamp(color, 0.0, 1.0);
    float vig = smoothstep(1.3, 0.48, length(uv / (PARAM_BASE_SCALE * 0.65)));
    color *= vig * 0.88 + 0.12;

    fragColor = vec4(color, 1.0);
}