import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

/**
 * 리딩 본문(LLM이 마크다운으로 생성)을 앱 톤에 맞춰 렌더한다.
 * raw HTML은 허용하지 않아(react-markdown 기본값) XSS 위험이 없다.
 * 이전에는 본문을 <p>에 그대로 넣어 **볼드**·목록이 날것으로 보였던 문제를 해결한다.
 */
export default function Markdown({ children }: { children: string }) {
  return (
    <div className="md">
      <ReactMarkdown remarkPlugins={[remarkGfm]}>{children}</ReactMarkdown>
    </div>
  );
}
