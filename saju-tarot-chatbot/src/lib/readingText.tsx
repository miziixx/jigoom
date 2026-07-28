/**
 * AI 리딩 텍스트 공용 파서/렌더러.
 * ReadingResult에서 추출해 작명 등 다른 결과 화면에서도 같은 규칙으로
 * "# 제목" 섹션과 "[소제목]" 파트를 렌더할 수 있게 한다. 동작은 추출 전과 동일하다.
 */

export interface Section {
  title: string;
  body: string;
}

export interface BodyPart {
  title: string | null;
  body: string;
}

export function parseSections(markdown: string): Section[] {
  const parts = markdown.split(/^#\s+(.+)$/m).slice(1);
  const sections: Section[] = [];
  for (let i = 0; i < parts.length; i += 2) {
    sections.push({ title: parts[i].trim(), body: (parts[i + 1] ?? "").trim() });
  }
  return sections.length > 0 ? sections : [{ title: "리딩 결과", body: markdown }];
}

export function parseBodyParts(text: string): BodyPart[] {
  const parts = text.split(/^\[([^\]]+)\]\s*$/m);
  if (parts.length <= 1) return [{ title: null, body: text }];

  const result: BodyPart[] = [];
  const intro = parts[0]?.trim();
  if (intro) result.push({ title: null, body: intro });
  for (let i = 1; i < parts.length; i += 2) {
    result.push({ title: parts[i].trim(), body: (parts[i + 1] ?? "").trim() });
  }
  return result.filter((part) => part.body.length > 0);
}

/**
 * 본문에서 마크다운 기호를 제거해 깔끔한 문장만 남긴다.
 * (모델이 실수로 넣어도 화면에 **, -, # 같은 기호가 보이지 않게 하는 방어선)
 * '분야별 요약'은 파싱을 먼저 끝낸 뒤라 여기서 정리해도 안전하다.
 */
export function stripMarkdown(text: string): string {
  return text
    .replace(/\*\*(.+?)\*\*/g, "$1") // **굵게**
    .replace(/__(.+?)__/g, "$1") // __굵게__
    .replace(/`([^`]+)`/g, "$1") // `코드`
    .replace(/^#{1,6}\s+/gm, "") // 본문 속 소제목
    .replace(/^\s*>\s?/gm, "") // 인용
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

export function renderTextBlock(text: string) {
  const blocks: JSX.Element[] = [];
  const lines = stripMarkdown(text).split("\n");
  let paragraph: string[] = [];
  let bullets: string[] = [];

  const flushParagraph = () => {
    const body = paragraph.join("\n").trim();
    if (body) {
      blocks.push(
        <p className="reading-body" key={`p-${blocks.length}`}>
          {body}
        </p>,
      );
    }
    paragraph = [];
  };

  const flushBullets = () => {
    if (bullets.length > 0) {
      blocks.push(
        <ul className="reading-bullets" key={`ul-${blocks.length}`}>
          {bullets.map((item, i) => (
            <li key={i}>{item}</li>
          ))}
        </ul>,
      );
    }
    bullets = [];
  };

  for (const line of lines) {
    const bullet = line.match(/^\s*[-*+]\s+(.+)$/);
    if (bullet) {
      flushParagraph();
      bullets.push(bullet[1].trim());
      continue;
    }
    if (!line.trim()) {
      flushParagraph();
      flushBullets();
      continue;
    }
    flushBullets();
    paragraph.push(line);
  }
  flushParagraph();
  flushBullets();

  return blocks.length > 0 ? blocks : null;
}
