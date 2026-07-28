import { useStore } from '../store/useStore';
import { OutlineNode } from './OutlineNode';

export function OutlineView() {
  const { nodes, rootIds, addNode } = useStore();

  const sortedRoots = rootIds
    .map(id => nodes[id])
    .filter(Boolean)
    .sort((a, b) => a.order - b.order);

  return (
    <div className="outline-view">
      {sortedRoots.map(node => (
        <OutlineNode key={node.id} node={node} depth={0} allNodes={nodes} />
      ))}
      <button className="add-root-btn" onClick={() => addNode(null)}>
        + 새 항목
      </button>
    </div>
  );
}
