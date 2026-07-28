import { Link } from "react-router-dom";

/**
 * "어떻게 계산하나요?" — 신뢰 배지 표면화 (C-3, 재기획안 §7 point 4).
 *
 * 이미 계산 엔진에 다 구현돼 있는 것들(진태양시·서머타임 보정, 4대 고전 교차검증, 계산 근거
 * 공개)을 사용자에게 처음으로 보여주는 페이지. §7: "기능은 전부 있음, 보여주기만 하면 됨."
 * PrivacyPage.tsx와 같은 카드 구조를 재사용한다. 한계는 정직하게 밝힌다(판본 이견 등).
 */
export default function MethodologyPage() {
  return (
    <section className="page privacy-page">
      <h2 className="page-title">어떻게 계산하나요?</h2>
      <p className="page-desc">
        인사이트 오라클은 느낌으로 운세를 말하지 않습니다. 태어난 시각을 최대한 정확히 보정하고, 그 결과를 명리학
        고전 여러 갈래로 교차 확인한 뒤, 계산에서 실제로 나온 것만 문장으로 옮깁니다.
      </p>

      <section className="card privacy-section">
        <h3 className="card-title">1. 태어난 시각부터 정확하게</h3>
        <ul className="reading-bullets">
          <li>
            <b>서머타임 보정</b> — 한국이 서머타임을 시행했던 기간에 태어났다면, 시계가 실제보다 1시간 빨랐던 만큼
            자동으로 되돌려 계산합니다.
          </li>
          <li>
            <b>진태양시 보정</b> — 표준시는 나라 전체가 같은 시각을 쓰지만, 태양이 실제로 그 자리에 뜨는 시각은
            지역마다 조금씩 다릅니다. 출생지를 선택하면 그 경도 차이만큼 시각을 보정합니다.
          </li>
        </ul>
        <p className="privacy-note">
          출생 시간을 모르거나 정확도가 낮다고 표시한 경우, 해당 부분에 크게 의존하는 해석은 단정을 피하고 조심스럽게
          다룹니다.
        </p>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">2. 명리 4대 고전으로 교차 확인</h3>
        <p>
          운세 앱 대부분은 하나의 간단한 규칙표로 결과를 냅니다. 인사이트 오라클은 계산 엔진 자체에 아래 네 갈래
          고전 이론을 반영해, 같은 사주를 여러 각도에서 다시 확인합니다.
        </p>
        <div className="privacy-table-wrap">
          <table className="privacy-table">
            <thead>
              <tr>
                <th>고전</th>
                <th>무엇을 보는가</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>자평진전(子平眞詮)</td>
                <td>타고난 그릇의 짜임새와, 그 그릇이 잘 짜였는지 흐트러졌는지</td>
              </tr>
              <tr>
                <td>연해자평(淵海子平)</td>
                <td>겉으로 드러난 성향과 속에 숨은 성향의 무게 차이</td>
              </tr>
              <tr>
                <td>궁통보감(窮通寶鑑)</td>
                <td>태어난 계절의 기운과, 그 기운을 데우거나 식혀줄 보완 기운</td>
              </tr>
              <tr>
                <td>삼명통회(三命通會)</td>
                <td>특이 신호(귀인·흉살 등)를 확장된 기준으로 추가 확인</td>
              </tr>
            </tbody>
          </table>
        </div>
        <p className="privacy-note">
          네 갈래 결과가 서로 같은 방향을 가리키면 해석에 더 확신을 싣고, 갈라지면 확신을 낮추고 조심스러운 표현을
          씁니다. 판정 결과가 만든 근거는 결과 화면의 "전문가 근거 보기"에서 확인할 수 있습니다.
        </p>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">3. 계산 근거는 전부 공개합니다</h3>
        <p>
          모든 리딩 결과 화면 하단에는 "계산 근거 자세히 보기"가 접혀 있습니다. 원국(사주 네 기둥), 오행 분포,
          대운·세운·월운 흐름, 그리고 위 4대 고전 판정 결과까지 — 문장 뒤에 어떤 계산이 있었는지 언제든 펼쳐 볼 수
          있습니다. 근거를 숨기지 않습니다.
        </p>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">한계도 정직하게</h3>
        <ul className="reading-bullets">
          <li>고전 이론은 유파·판본마다 세부 해석이 갈리는 경우가 있습니다. 1순위 판정은 여러 통용본과 대조했지만,
            2·3순위 세부값은 참고서마다 다를 수 있습니다.</li>
          <li>계산은 태어난 시각과 장소를 근거로 한 통계적 경향입니다. 확정된 미래를 말하지 않으며, 의학·법률·투자
            같은 중대한 결정의 근거로 쓰지 않는 것을 권합니다.</li>
          <li>출생 시간이 불확실하면 그 사실을 결과에 함께 표시합니다.</li>
        </ul>
      </section>

      <Link to="/" className="btn btn--ghost">
        홈으로 돌아가기
      </Link>
    </section>
  );
}
