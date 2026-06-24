import { useRef, useEffect, type KeyboardEvent } from 'react';
import { useStore, getChildIds } from '../store/useStore';
import type { MindNode } from '../store/types';

interface Props {
  node: MindNode;
  depth: number;
  allNodes: Record<string, MindNode>;
}

export function OutlineNode({ node, depth, allNodes }: Props) {
  const { updateText, addNode, deleteNode, indentNode, unindentNode,
          toggleCollapse, setSelected, selectedId, removeRef, setNodeDate } = useStore();
  const inputRef = useRef<HTMLTextAreaElement>(null);
  const isSelected = selectedId === node.id;
  const children = getChildIds({ nodes: allNodes }, node.id);
  const hasChildren = children.length > 0;

  useEffect(() => {
    if (isSelected && inputRef.current) inputRef.current.focus();
  }, [isSelected]);

  function handleKeyDown(e: KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      if (depth === 0) {
        e.preventDefault();
        addNode(node.parentId, node.id);
      }
      // depth >= 1: 기본 줄바꿈
    }
    if (e.key === 'Tab') {
      e.preventDefault();
      if (e.shiftKey) unindentNode(node.id);
      else indentNode(node.id);
    }
    if (e.key === 'Backspace' && node.text === '') {
      e.preventDefault();
      deleteNode(node.id);
    }
  }

  function autoResize(el: HTMLTextAreaElement) {
    el.style.height = 'auto';
    el.style.height = el.scrollHeight + 'px';
  }

  const refNodes = node.refs.map(r => allNodes[r]).filter(Boolean);

  return (
    <div style={{ marginLeft: depth === 0 ? 0 : 20 }}>
      <div
        className={`outline-row ${isSelected ? 'selected' : ''}`}
        onClick={() => setSelected(node.id)}
      >
        <span
          className="collapse-btn"
          onClick={e => { e.stopPropagation(); if (hasChildren) toggleCollapse(node.id); }}
        >
          {hasChildren ? (node.collapsed ? '▶' : '▼') : '•'}
        </span>
        <textarea
          ref={inputRef}
          className="outline-input"
          value={node.text}
          placeholder="내용 입력..."
          rows={1}
          onChange={e => { updateText(node.id, e.target.value); autoResize(e.target); }}
          onKeyDown={handleKeyDown}
          onFocus={() => setSelected(node.id)}
        />

        {/* 날짜 배지 */}
        {node.date && (
          <span
            className="outline-date-badge"
            title="날짜 클릭해서 변경"
            onClick={e => {
              e.stopPropagation();
              const el = e.currentTarget.nextElementSibling as HTMLInputElement | null;
              el?.showPicker?.();
            }}
          >
            🗓 {node.date}
          </span>
        )}
        <input
          type="date"
          className="outline-date-hidden"
          value={node.date ?? ''}
          onChange={e => setNodeDate(node.id, e.target.value || null)}
          onClick={e => e.stopPropagation()}
          tabIndex={-1}
        />
        <button
          className="outline-date-btn"
          title="날짜 지정"
          onClick={e => {
            e.stopPropagation();
            const input = e.currentTarget.previousElementSibling as HTMLInputElement | null;
            input?.showPicker?.();
          }}
        >🗓</button>

        {/* 교차연결 칩 */}
        {refNodes.length > 0 && (
          <div className="ref-chips">
            {refNodes.map(r => (
              <span key={r.id} className="ref-chip" title="교차연결">
                ↗ {r.text || '(빈 노드)'}
                <button className="ref-chip-del" onClick={e => { e.stopPropagation(); removeRef(node.id, r.id); }}>×</button>
              </span>
            ))}
          </div>
        )}
      </div>
      {!node.collapsed && children.map(childId => (
        <OutlineNode key={childId} node={allNodes[childId]} depth={depth + 1} allNodes={allNodes} />
      ))}
    </div>
  );
}
