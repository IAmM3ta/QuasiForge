// QuasiForge — Audio-reactive quasicrystal with physics-inspired layers
// Core algorithm: iterative sum-of-plane-waves (classic construction from mainisusuallyafunction 2011)
// Extended with: Rayleigh scattering, iridescence (structural color), height-field extrusion,
// mirroring (H/V/quad), dispersion (chromatic), octave layering, full manual + audio control.
//
// Shadertoy compatible (iTime, iResolution, iMouse, iChannel0 for audio spectrum).
// In Shadertoy: attach audio to iChannel0. Drag mouse to control primary parameters.
// For full "slider" experience edit the PARAM_* defaults or remap iMouse lines below.
//
// === CONTROLS (Shadertoy) ===
// iMouse.x (0..1) : Manual Scale + Time Rate (primary interaction)
// iMouse.y (0..1) : Dispersion + Color Spectrum / Audio Sensitivity
// Edit constants below for precise "sliders" or add more mouse mappings.
// Audio bands are mapped to distinct seeds (see detailed comments below).

#define PI 3.141592653589793
#define N 7                    // Base symmetry (quasicrystal order). Change and recompile for different N.

// ==================== MANUAL PARAMETERS (edit these for precise control / "sliders") ====================
const float PARAM_BASE_SCALE      = 7.5;     // Base pattern scale
const float PARAM_TIME_RATE       = 1.0;     // Base animation speed multiplier (twist/warp rate)
const float PARAM_DISPERSION      = 0.035;   // Chromatic dispersion strength (per-channel scale/phase offset)
const float PARAM_AUDIO_SENS      = 1.0;     // Audio sensitivity multiplier
const float PARAM_COLOR_HUE_SHIFT = 0.0;     // Manual color spectrum / hue offset
const float PARAM_INVERT          = 0.0;     // 0.0 = normal, >0.5 = color inversion
const float PARAM_OCTAVES         = 1.5;     // Octave layering amount (1.0 = single layer, >1 adds higher octave)
const float PARAM_EXTRUSION       = 0.6;     // Height-field extrusion strength (normal shading intensity)
const float PARAM_MIRROR_MODE     = 0.0;     // 0=none, 1=horizontal, 2=vertical, 3=quad (or use iMouse button logic)

// ==================== AUDIO MAPPING (detailed) ====================
// bass  (low freq)  -> global scale breathing, Rayleigh scatter amount, initial direction seed perturbation
// mids  (mid freq)  -> per-wave phase diversity, base hue, iridescence mix, octave weighting
// highs (high freq) -> animation speed, micro phase jitter, iridescence hue velocity, dispersion dynamics
// All multiplied by PARAM_AUDIO_SENS for manual sensitivity control.

mat2 rot(float a) {
    float c = cos(a), s = sin(a);
    return mat2(c, s, -s, c);
}

vec3 hsv2rgb(vec3 c) {
    vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    rgb = rgb * rgb * (3.0 - 2.0 * rgb);
    return c.z * mix(vec3(1.0), rgb, c.y);
}

// Mirroring function (horizontal, vertical, quad)
vec2 applyMirror(vec2 uv, float mode) {
    if (mode > 2.5) {          // Quad
        uv = abs(uv);
    } else if (mode > 1.5) {   // Vertical
        uv.y = abs(uv.y);
    } else if (mode > 0.5) {   // Horizontal
        uv.x = abs(uv.x);
    }
    return uv;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // --- Audio sampling + sensitivity ---
    float sens = PARAM_AUDIO_SENS * (1.0 + iMouse.y * 0.8); // manual audio sensitivity via mouse Y
    float bass  = texture(iChannel0, vec2(0.07, 0.25)).x * sens;
    float mids  = texture(iChannel0, vec2(0.27, 0.25)).x * sens;
    float highs = texture(iChannel0, vec2(0.62, 0.25)).x * sens;

    // --- Manual + audio-reactive scale ---
    float manualScale = PARAM_BASE_SCALE * (1.0 + iMouse.x * 1.8); // mouse X primary scale control
    float audioScale  = 1.0 + bass * 0.65;
    float scale = manualScale * audioScale;

    // --- Time & time-rate (twist/warp/distort speed) ---
    float timeRate = PARAM_TIME_RATE * (1.0 + iMouse.x * 0.9); // mouse X also influences rate
    float t = iTime * timeRate * (1.0 + highs * 2.8);

    // --- Mirroring ---
    float mirrorMode = PARAM_MIRROR_MODE;
    // Optional: use mouse click or another mapping for mode (here fixed; edit PARAM or extend)
    uv = applyMirror(uv, mirrorMode);

    // --- Dispersion (chromatic) preparation ---
    float disp = PARAM_DISPERSION * (1.0 + iMouse.y * 1.2 + highs * 0.4);

    // --- Core wave sum with dispersion per channel hint (we compute base + offsets) ---
    vec2 up = vec2(scale, 0.0);
    float seedPerturb = (bass - 0.5) * 0.11;
    up = rot(seedPerturb) * up;

    float angleStep = PI / float(N) + (mids - 0.5) * 0.018;
    mat2 rmat = rot(angleStep);

    float sumR = 0.0, sumG = 0.0, sumB = 0.0; // for dispersion

    for (int i = 0; i < N; i++) {
        float phaseBase = t + float(i) * (1.15 + mids * 1.55);
        float jitter = highs * sin(float(i) * 2.4) * 0.6;

        // Base sum
        float ph = phaseBase + jitter;
        float contrib = cos(dot(uv, up) + ph);
        sumR += contrib;
        sumG += contrib;
        sumB += contrib;

        // Dispersion offsets (slightly different effective scale/phase per "wavelength")
        float dispScaleR = 1.0 + disp * 1.0;
        float dispScaleG = 1.0 + disp * 0.0;
        float dispScaleB = 1.0 - disp * 1.2;

        // Approximate per-channel by slight phase or direction perturbation (cheap)
        sumR += cos(dot(uv * dispScaleR, up) + ph + disp * 2.0) * 0.35;
        sumG += cos(dot(uv * dispScaleG, up) + ph) * 0.35;
        sumB += cos(dot(uv * dispScaleB, up) + ph - disp * 2.5) * 0.35;

        up = rmat * up;
    }

    // Average
    sumR /= float(N) * 1.35;
    sumG /= float(N) * 1.35;
    sumB /= float(N) * 1.35;

    // Interference wrap (per channel for dispersion feel)
    float IR = (cos(sumR * 0.52 + 2.05) + 1.0) * 0.5;
    float IG = (cos(sumG * 0.52 + 2.05) + 1.0) * 0.5;
    float IB = (cos(sumB * 0.52 + 2.05) + 1.0) * 0.5;

    float I = (IR + IG + IB) / 3.0; // combined interference for lighting/extrusion

    // --- Octave layering (second higher-frequency layer) ---
    float octaveAmt = PARAM_OCTAVES + mids * 0.6;
    if (octaveAmt > 1.01) {
        // Quick second pass at higher frequency (reuse rotation but different scale/phase)
        float octScale = scale * 2.618;
        vec2 up2 = vec2(octScale, 0.0);
        up2 = rot(seedPerturb * 0.7) * up2;
        float sumOct = 0.0;
        for (int j = 0; j < N; j++) {
            float ph2 = t * 1.3 + float(j) * (1.6 + mids * 1.2);
            sumOct += cos(dot(uv, up2) + ph2);
            up2 = rmat * up2;
        }
        float IOct = (cos(sumOct * 0.48 + 1.8) + 1.0) * 0.5;
        I = mix(I, IOct, (octaveAmt - 1.0) * 0.6);
        // Blend color channels lightly
        IR = mix(IR, IOct, 0.3);
        IG = mix(IG, IOct, 0.3);
        IB = mix(IB, IOct, 0.3);
    }

    // --- Base color with manual spectrum/hue adjustment ---
    float hue = I * 0.38 + t * 0.022 + mids * 0.16 + PARAM_COLOR_HUE_SHIFT + iMouse.y * 0.25;
    vec3 baseCol = hsv2rgb(vec3(mod(hue, 1.0), 0.76, 0.87 + I * 0.13));

    // --- Iridescence ---
    float film = (sumR + sumG + sumB) * 0.6 + uv.x * 0.32 + t * 0.07;
    vec3 irid;
    irid.r = (cos(film * 6.65) + 1.0) * 0.5;
    irid.g = (cos(film * 7.8 + 1.2) + 1.0) * 0.5;
    irid.b = (cos(film * 8.95 + 2.5) + 1.0) * 0.5;

    float iridMix = 0.60 + highs * 0.32 + iMouse.y * 0.15;
    vec3 color = mix(baseCol * vec3(IR, IG, IB), irid, iridMix);

    // --- Rayleigh scattering (audio + manual) ---
    float scatter = 0.52 + bass * 0.85;
    vec3 rayleigh = vec3(0.065, 0.19, 0.90) * scatter * (1.0 - I * 0.5);
    color += rayleigh;

    // --- Height-field extrusion (fake normal shading) ---
    float extrude = PARAM_EXTRUSION * (1.0 + mids * 0.4);
    if (extrude > 0.01) {
        float eps = 0.8 / scale;
        // Recompute I at offset positions for normal (cheap approximation reusing sums conceptually)
        // For performance we approximate gradient from existing I variation
        vec2 dUVx = vec2(eps, 0.0);
        vec2 dUVy = vec2(0.0, eps);
        // Simple central difference approximation on interference
        float Ix = (cos((sumR + 0.8) * 0.52 + 2.05) + 1.0) * 0.5; // rough proxy
        float Iy = (cos((sumG - 0.6) * 0.52 + 2.05) + 1.0) * 0.5;
        vec3 normal = normalize(vec3((I - Ix) * 12.0, (I - Iy) * 12.0, 1.0));
        vec3 lightDir = normalize(vec3(0.6, 0.7, 1.2));
        float diff = max(dot(normal, lightDir), 0.15);
        color *= mix(1.0, diff, extrude * 0.7);
        // Subtle specular
        float spec = pow(max(dot(reflect(-lightDir, normal), vec3(0.0,0.0,1.0)), 0.0), 18.0);
        color += spec * extrude * 0.35 * vec3(0.9, 0.95, 1.0);
    }

    // --- Color inversion ---
    if (PARAM_INVERT > 0.5) {
        color = 1.0 - color;
    }

    // Polish
    color = pow(color, vec3(0.83));
    color = clamp(color, 0.0, 1.0);

    // Vignette
    float vig = smoothstep(1.25, 0.5, length(uv / (PARAM_BASE_SCALE * 0.7)));
    color *= vig * 0.9 + 0.1;

    fragColor = vec4(color, 1.0);
}