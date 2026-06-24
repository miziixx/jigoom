import { useStore } from '../store/useStore';

interface SliderProps {
  label: string;
  value: number;
  min: number;
  max: number;
  onChange: (v: number) => void;
  gradient?: string;
}

function Slider({ label, value, min, max, onChange, gradient }: SliderProps) {
  return (
    <div className="settings-slider-row">
      <div className="settings-slider-top">
        <span className="settings-slider-label">{label}</span>
        <span className="settings-slider-value">{value}</span>
      </div>
      <input
        type="range"
        className="settings-range"
        min={min}
        max={max}
        value={value}
        onChange={e => onChange(Number(e.target.value))}
        style={gradient ? { '--slider-gradient': gradient } as React.CSSProperties : undefined}
      />
    </div>
  );
}

function hueGradient(sat: number, light: number) {
  return `linear-gradient(to right,
    hsl(0,${sat}%,${light}%), hsl(45,${sat}%,${light}%),
    hsl(90,${sat}%,${light}%), hsl(135,${sat}%,${light}%),
    hsl(180,${sat}%,${light}%), hsl(225,${sat}%,${light}%),
    hsl(270,${sat}%,${light}%), hsl(315,${sat}%,${light}%),
    hsl(360,${sat}%,${light}%))`;
}

export function SettingsPanel() {
  const { settingsOpen, setSettingsOpen, theme, setTheme, resetTheme } = useStore();
  if (!settingsOpen) return null;

  const bgPreview = `hsl(${theme.bgHue},${theme.bgSat}%,${theme.bgLight}%)`;
  const textPreview = `hsl(${theme.textHue},${theme.textSat}%,${theme.textLight}%)`;

  return (
    <div className="settings-overlay" onClick={() => setSettingsOpen(false)}>
      <div className="settings-panel" onClick={e => e.stopPropagation()}>
        <div className="settings-header">
          <span className="settings-title">⚙ 설정</span>
          <button className="settings-close" onClick={() => setSettingsOpen(false)}>✕</button>
        </div>

        {/* 미리보기 */}
        <div className="settings-preview" style={{ background: bgPreview }}>
          <span style={{ color: textPreview, fontWeight: 600 }}>미리보기 텍스트</span>
          <span style={{ color: textPreview, opacity: 0.5, fontSize: 12 }}>보조 텍스트</span>
        </div>

        <div className="settings-section">
          <p className="settings-section-title">배경색</p>

          <Slider
            label="색조 (Hue)"
            value={theme.bgHue}
            min={0} max={360}
            onChange={v => setTheme({ bgHue: v })}
            gradient={hueGradient(theme.bgSat, theme.bgLight)}
          />
          <Slider
            label="채도 (Saturation)"
            value={theme.bgSat}
            min={0} max={30}
            onChange={v => setTheme({ bgSat: v })}
            gradient={`linear-gradient(to right, hsl(${theme.bgHue},0%,${theme.bgLight}%), hsl(${theme.bgHue},30%,${theme.bgLight}%))`}
          />
          <Slider
            label="밝기 (Lightness)"
            value={theme.bgLight}
            min={4} max={22}
            onChange={v => setTheme({ bgLight: v })}
            gradient={`linear-gradient(to right, hsl(${theme.bgHue},${theme.bgSat}%,4%), hsl(${theme.bgHue},${theme.bgSat}%,22%))`}
          />
        </div>

        <div className="settings-section">
          <p className="settings-section-title">폰트색</p>

          <Slider
            label="색조 (Hue)"
            value={theme.textHue}
            min={0} max={360}
            onChange={v => setTheme({ textHue: v })}
            gradient={hueGradient(theme.textSat, theme.textLight)}
          />
          <Slider
            label="채도 (Saturation)"
            value={theme.textSat}
            min={0} max={40}
            onChange={v => setTheme({ textSat: v })}
            gradient={`linear-gradient(to right, hsl(${theme.textHue},0%,${theme.textLight}%), hsl(${theme.textHue},40%,${theme.textLight}%))`}
          />
          <Slider
            label="밝기 (Lightness)"
            value={theme.textLight}
            min={60} max={100}
            onChange={v => setTheme({ textLight: v })}
            gradient={`linear-gradient(to right, hsl(${theme.textHue},${theme.textSat}%,60%), hsl(${theme.textHue},${theme.textSat}%,100%))`}
          />
        </div>

        <button className="settings-reset" onClick={resetTheme}>
          기본값으로 초기화
        </button>
      </div>
    </div>
  );
}
