import { useState } from 'react';
import { useStore } from '../store/useStore';

export function BacklinkPanel() {
  const { nodes, selectedId, setSelected, addRef, removeRef } = useStore();
  const [refSearch, setRefSearch] = useState('');

  if (!selectedId) {
    return (
      <div className="backlink-panel">
        <p className="backlink-empty">노드를 선택하면 연결 정보가 표시됩니다.</p>
      </div>
    );
  }

  const node = nodes[selectedId];
  if (!node) return null;

  const parent = node.parentId ? nodes[node.parentId] : null;
  const backlinks = Object.values(nodes).filter(n => n.refs.includes(selectedId));
  const outRefs = node.refs.map(r => nodes[r]).filter(Boolean);

  const candidates = refSearch.trim()
    ? Object.values(nodes).filter(
        n => n.id !== selectedId &&
          !node.refs.includes(n.id) &&
          n.text.includes(refSearch.trim())
      ).slice(0, 8)
    : [];

  return (
    <div className="backlink-panel">
      <div className="backlink-section">
        <span className="backlink-label">선택</span>
        <span className="backlink-node-name">{node.text || '(빈 노드)'}</span>
      </div>

      {parent && (
        <div className="backlink-section">
          <span className="backlink-label">부모</span>
          <button className="backlink-link" onClick={() => setSelected(parent.id)}>
            {parent.text || '(빈 노드)'}
          </button>
        </div>
      )}

      <div className="backlink-section">
        <span className="backlink-label">나를 참조하는 노드</span>
        {backlinks.length === 0 ? (
          <span className="backlink-none">없음</span>
        ) : (
          <div className="backlink-list">
            {backlinks.map(b => (
              <button key={b.id} className="backlink-link" onClick={() => setSelected(b.id)}>
                ↙ {b.text || '(빈 노드)'}
              </button>
            ))}
          </div>
        )}
      </div>

      <div className="backlink-section">
        <span className="backlink-label">내가 참조하는 노드</span>
        {outRefs.length === 0 ? (
          <span className="backlink-none">없음</span>
        ) : (
          <div className="backlink-list">
            {outRefs.map(r => (
              <span key={r.id} className="backlink-ref-item">
                <button className="backlink-link" onClick={() => setSelected(r.id)}>
                  ↗ {r.text || '(빈 노드)'}
                </button>
                <button className="backlink-unref" onClick={() => removeRef(selectedId, r.id)}>×</button>
              </span>
            ))}
          </div>
        )}
      </div>

      <div className="backlink-section backlink-add-ref">
        <span className="backlink-label">교차연결 추가</span>
        <input
          className="backlink-search"
          placeholder="노드 이름 검색..."
          value={refSearch}
          onChange={e => setRefSearch(e.target.value)}
        />
        {candidates.length > 0 && (
          <div className="backlink-candidates">
            {candidates.map(c => (
              <button
                key={c.id}
                className="backlink-candidate-btn"
                onClick={() => { addRef(selectedId, c.id); setRefSearch(''); }}
              >
                ↗ {c.text || '(빈 노드)'}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
