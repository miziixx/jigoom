import React, { useCallback, useMemo } from 'react';
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Handle,
  Position,
} from '@xyflow/react';
import type { NodeChange, Node, Edge, NodeProps } from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { useStore } from '../store/useStore';
import type { MindNode } from '../store/types';

function MindMapNode({ data, selected }: NodeProps) {
  const { addNode, updateText, setSelected, deleteNode } = useStore();
  const d = data as { node: MindNode };
  const node = d.node;

  return (
    <div
      className={`mm-node ${selected ? 'mm-node--selected' : ''}`}
      onClick={() => setSelected(node.id)}
      onDoubleClick={() => addNode(node.id)}
    >
      <Handle type="target" position={Position.Left} style={{ opacity: 0 }} />
      <input
        className="mm-node-input"
        value={node.text}
        placeholder="노드..."
        onChange={e => updateText(node.id, e.target.value)}
        onClick={e => e.stopPropagation()}
      />
      <button
        className="mm-node-del"
        onClick={e => { e.stopPropagation(); deleteNode(node.id); }}
        title="삭제"
      >×</button>
      <Handle type="source" position={Position.Right} style={{ opacity: 0 }} />
    </div>
  );
}

const nodeTypes = { mindmap: MindMapNode };

function buildFlowData(nodes: Record<string, MindNode>) {
  const flowNodes: Node[] = [];
  const flowEdges: Edge[] = [];

  Object.values(nodes).forEach(n => {
    flowNodes.push({
      id: n.id,
      type: 'mindmap',
      position: n.position,
      data: { node: n },
    });

    if (n.parentId && nodes[n.parentId]) {
      flowEdges.push({
        id: `tree-${n.parentId}-${n.id}`,
        source: n.parentId,
        target: n.id,
        style: { stroke: '#555', strokeWidth: 2 },
      });
    }

    n.refs.forEach(refId => {
      if (nodes[refId]) {
        flowEdges.push({
          id: `ref-${n.id}-${refId}`,
          source: n.id,
          target: refId,
          style: { stroke: '#7c3aed', strokeWidth: 1.5, strokeDasharray: '6 3' },
          animated: true,
          label: '참조',
          labelStyle: { fontSize: 10, fill: '#7c3aed' },
        });
      }
    });
  });

  return { flowNodes, flowEdges };
}

export function MindMapView() {
  const { nodes, addNode, updatePosition, setSelected } = useStore();
  const { flowNodes, flowEdges } = useMemo(() => buildFlowData(nodes), [nodes]);

  const onNodesChange = useCallback((changes: NodeChange[]) => {
    changes.forEach(change => {
      if (change.type === 'position' && change.position) {
        updatePosition(change.id, change.position.x, change.position.y);
      }
    });
  }, [updatePosition]);

  const onNodeClick = useCallback((_: React.MouseEvent, node: Node) => {
    setSelected(node.id);
  }, [setSelected]);

  const onPaneClick = useCallback(() => setSelected(null), [setSelected]);

  return (
    <div style={{ width: '100%', height: '100%' }}>
      <ReactFlow
        nodes={flowNodes}
        edges={flowEdges}
        nodeTypes={nodeTypes}
        onNodesChange={onNodesChange}
        onNodeClick={onNodeClick}
        onPaneClick={onPaneClick}
        fitView
        fitViewOptions={{ padding: 0.2 }}
      >
        <Background color="#2a2a2a" gap={20} />
        <Controls />
        <MiniMap nodeColor="#555" maskColor="rgba(0,0,0,0.7)" />
      </ReactFlow>
      <button
        className="mm-add-root-btn"
        onClick={() => addNode(null)}
      >
        + 루트 노드
      </button>
    </div>
  );
}
