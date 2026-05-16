# QuasiForge

Audio-reactive quasicrystal shader featuring Rayleigh scattering, structural iridescence, height-field extrusion, chromatic dispersion, octave layering, mirroring, and extensive manual + audio controls.

Built on the classic iterative sum-of-plane-waves construction (see mainisusuallyafunction.blogspot.com/2011/10/quasicrystals-as-sums-of-waves-in-plane.html and early Shadertoy ports). Extended with physically motivated optical effects and rich interactivity.

## Features
- **Core**: N-fold rotational symmetry quasicrystal via iterative direction rotation and cosine summation + interference wrap.
- **Audio Reactivity**: Distinct mapping of bass/mids/highs to scale breathing, phase diversity, animation speed, Rayleigh amount, iridescence dynamics, and seed perturbations.
- **Rayleigh Scattering**: Blue-dominant atmospheric scatter modulated by audio and local interference density.
- **Iridescence**: Per-channel thin-film/structural color simulation driven by wave sum (photonic quasicrystal aesthetic).
- **Height-Field Extrusion**: Fake normals + diffuse/specular shading from the interference field for pseudo-3D relief.
- **Chromatic Dispersion**: Per-RGB scale/phase offsets inside the wave loop for colorful fringing.
- **Octave Layering**: Optional second higher-frequency quasicrystal layer blended in.
- **Mirroring**: Horizontal, vertical, or quad (both axes) symmetry modes.
- **Manual Controls**: PARAM_* constants act as precise sliders. iMouse provides real-time interaction (X = scale/time-rate, Y = dispersion/sensitivity/hue).
- **Inversion & Color Spectrum**: Toggle inversion and manual hue/spectrum shift.
- **Time-Rate Control**: Independent multiplier on animation speed for twisting/warping feel.
- **Audio Sensitivity**: Global multiplier on spectrum input.

## Usage in Shadertoy
1. Create a new shader.
2. Paste the entire contents of `quasi_forge.glsl` into the Image tab.
3. (Recommended) Attach an audio source (mp3, mic, or sound buffer) to **iChannel0**.
4. The shader runs immediately.
5. **Mouse interaction**:
   - Drag horizontally (X): primarily controls manual scale and time-rate (twist speed).
   - Drag vertically (Y): influences dispersion strength, audio sensitivity, and color/hue.
6. For precise "slider" control: edit the `PARAM_*` constants at the top of the file (they act as dedicated sliders). Recompile to apply.
7. Change `N` define for different rotational symmetries (5, 7, 9 recommended).

## Parameters (edit in code for fine control)
- `PARAM_BASE_SCALE` — overall pattern zoom.
- `PARAM_TIME_RATE` — speed of twisting/warping/distortion.
- `PARAM_DISPERSION` — strength of chromatic separation.
- `PARAM_AUDIO_SENS` — how strongly audio drives the system.
- `PARAM_COLOR_HUE_SHIFT` — manual color spectrum offset.
- `PARAM_INVERT` — set > 0.5 for color inversion.
- `PARAM_OCTAVES` — amount of second octave layering.
- `PARAM_EXTRUSION` — height-field shading intensity.
- `PARAM_MIRROR_MODE` — 0=none, 1=horizontal, 2=vertical, 3=quad.

## Audio Mapping (detailed)
- **Bass** (low): scale pulsing, Rayleigh haze amount, initial seed direction perturbation.
- **Mids** (mid): per-wave phase diversity, base coloring, iridescence mix, octave blend weight.
- **Highs** (high): animation rate, micro-jitter, iridescence velocity, dispersion dynamics.

All audio values are scaled by `PARAM_AUDIO_SENS` (and further modulated by mouse Y).

## Optimization Notes
- Single-pass, minimal trig calls outside the small N=7 loop.
- Dispersion and octave use cheap approximations inside existing loops.
- Height-field normal uses efficient proxy (no extra full wave summations).
- Suitable for real-time 1080p+ on modern GPUs.

## License / Credits
Core algorithm inspired by the 2011 sum-of-waves quasicrystal work and community ports.  
All extensions, audio mapping, optical layers, and controls by the QuasiForge project.

Enjoy forging interference patterns with sound and light.