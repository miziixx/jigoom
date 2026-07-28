import { useState } from "react";
import { useNavigate } from "react-router-dom";

// 집안일에 붙는 💡 노하우 팁 카드 (기획서 13장·3-5).
export default function TipCard({ tip, howtoId }: { tip?: string; howtoId?: string }) {
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  if (!tip) return null;

  return (
    <div className="tipcard">
      <button className="tipcard-head" onClick={() => setOpen((v) => !v)}>
        <span>💡 팁</span>
        <span className="tipcard-toggle">{open ? "접기" : "펼치기"}</span>
      </button>
      {open && (
        <div className="tipcard-body">
          <p>{tip}</p>
          {howtoId && (
            <button
              className="link-btn"
              onClick={() => navigate(`/encyclopedia?id=${howtoId}`)}
            >
              더 자세히 →
            </button>
          )}
        </div>
      )}
    </div>
  );
}
