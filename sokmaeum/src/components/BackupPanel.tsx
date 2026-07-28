import { useRef, useState } from "react";
import { downloadBackup, importSessions } from "../lib/backup";

interface Props {
  /** 복원 후 히스토리 새로고침 */
  onImported?: () => void;
}

/** 챗봇 대화 백업 — 내보내기 / 가져오기(병합·덮어쓰기) */
export default function BackupPanel({ onImported }: Props) {
  const fileRef = useRef<HTMLInputElement>(null);
  const [mode, setMode] = useState<"merge" | "replace">("merge");
  const [status, setStatus] = useState<string | null>(null);

  function handlePick() {
    fileRef.current?.click();
  }

  async function handleFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    const result = importSessions(text, mode);
    setStatus(result.message);
    if (result.ok) onImported?.();
    // 같은 파일 재선택 가능하도록 초기화
    if (fileRef.current) fileRef.current.value = "";
  }

  return (
    <div className="card backup-panel">
      <h4>대화 백업</h4>
      <p className="field-hint">
        모든 리딩·챗봇 대화를 JSON 파일로 저장하거나 복원할 수 있어요. 기기를 바꾸거나 데이터를 초기화하기 전에
        내보내 두면 안전합니다. (이 기기에만 저장되며 서버로 전송되지 않습니다.)
      </p>
      <div className="field-row">
        <button className="btn btn--secondary" onClick={downloadBackup}>
          대화 내보내기
        </button>
        <label className="backup-mode">
          <input type="radio" name="backup-mode" checked={mode === "merge"} onChange={() => setMode("merge")} /> 병합
        </label>
        <label className="backup-mode">
          <input type="radio" name="backup-mode" checked={mode === "replace"} onChange={() => setMode("replace")} /> 덮어쓰기
        </label>
        <button className="btn btn--ghost" onClick={handlePick}>
          대화 가져오기
        </button>
        <input ref={fileRef} type="file" accept="application/json,.json" onChange={handleFile} hidden />
      </div>
      {status && <p className="field-hint">{status}</p>}
    </div>
  );
}
