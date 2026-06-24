import { useMemo } from 'react';
import { useStore } from '../store/useStore';

const WEEKDAYS = ['일', '월', '화', '수', '목', '금', '토'];

function getDaysInMonth(year: number, month: number) {
  return new Date(year, month + 1, 0).getDate();
}

function getFirstDayOfWeek(year: number, month: number) {
  return new Date(year, month, 1).getDay();
}

export function CalendarView() {
  const { nodes, calendarMonth, setCalendarMonth, setSelected, setViewMode, setNodeDate, selectedId } = useStore();

  const [year, month] = calendarMonth.split('-').map(Number);
  const monthIndex = month - 1;

  const daysInMonth = getDaysInMonth(year, monthIndex);
  const firstDow = getFirstDayOfWeek(year, monthIndex);

  // group nodes by date
  const nodesByDate = useMemo(() => {
    const map: Record<string, typeof nodes[string][]> = {};
    Object.values(nodes).forEach(n => {
      if (n.date) {
        if (!map[n.date]) map[n.date] = [];
        map[n.date].push(n);
      }
    });
    return map;
  }, [nodes]);

  function prevMonth() {
    const d = new Date(year, monthIndex - 1, 1);
    setCalendarMonth(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  }

  function nextMonth() {
    const d = new Date(year, monthIndex + 1, 1);
    setCalendarMonth(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
  }

  function handleNodeClick(id: string) {
    setSelected(id);
    setViewMode('outline');
  }

  const today = new Date();
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;

  // Build grid cells: leading blanks + day cells
  const cells: (number | null)[] = [
    ...Array(firstDow).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];
  // pad to complete last row
  while (cells.length % 7 !== 0) cells.push(null);

  return (
    <div className="calendar-view">
      <div className="cal-header">
        <button className="cal-nav-btn" onClick={prevMonth}>‹</button>
        <span className="cal-title">{year}년 {month}월</span>
        <button className="cal-nav-btn" onClick={nextMonth}>›</button>
      </div>

      <div className="cal-grid">
        {WEEKDAYS.map(d => (
          <div key={d} className="cal-weekday">{d}</div>
        ))}
        {cells.map((day, i) => {
          if (day === null) return <div key={`blank-${i}`} className="cal-cell cal-cell--blank" />;
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
          const dayNodes = nodesByDate[dateStr] ?? [];
          const isToday = dateStr === todayStr;
          return (
            <div key={dateStr} className={`cal-cell ${isToday ? 'cal-cell--today' : ''}`}>
              <span className="cal-day-num">{day}</span>
              <div className="cal-node-list">
                {dayNodes.slice(0, 3).map(n => (
                  <button
                    key={n.id}
                    className={`cal-node-chip ${selectedId === n.id ? 'active' : ''}`}
                    onClick={() => handleNodeClick(n.id)}
                    title={n.text}
                  >
                    {n.text || '(빈 노드)'}
                  </button>
                ))}
                {dayNodes.length > 3 && (
                  <span className="cal-more">+{dayNodes.length - 3}</span>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* 선택 노드에 날짜 할당 */}
      {selectedId && nodes[selectedId] && (
        <div className="cal-assign-bar">
          <span className="cal-assign-label">
            선택 중: <strong>{nodes[selectedId].text || '(빈 노드)'}</strong>
          </span>
          <input
            type="date"
            className="cal-date-input"
            value={nodes[selectedId].date ?? ''}
            onChange={e => setNodeDate(selectedId, e.target.value || null)}
          />
          {nodes[selectedId].date && (
            <button className="cal-date-clear" onClick={() => setNodeDate(selectedId, null)}>
              날짜 삭제
            </button>
          )}
        </div>
      )}
    </div>
  );
}
