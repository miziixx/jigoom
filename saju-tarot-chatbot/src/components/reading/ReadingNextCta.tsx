import { Link } from "react-router-dom";
import { VizIcon } from "../viz/icons";

export interface NextCtaItem {
  to: string;
  label: string;
  icon: string;
  desc?: string;
}

/** 리딩이 끝난 뒤 이어갈 다음 행동 제안. 템플릿별로 항목이 다르다. */
export default function ReadingNextCta({ title = "이어서 보면 좋은 것", items }: { title?: string; items: NextCtaItem[] }) {
  if (items.length === 0) return null;
  return (
    <section className="card reading-cta" aria-label="다음 리딩 제안">
      <h3 className="card-title">{title}</h3>
      <div className="reading-cta__grid">
        {items.map((item) => (
          <Link className="reading-cta__item" to={item.to} key={item.to + item.label}>
            <span className="reading-cta__icon">
              <VizIcon name={item.icon} size={16} />
            </span>
            <b>{item.label}</b>
            {item.desc && <small>{item.desc}</small>}
          </Link>
        ))}
      </div>
    </section>
  );
}
