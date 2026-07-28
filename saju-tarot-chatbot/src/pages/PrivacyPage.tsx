import { Link } from "react-router-dom";

const UPDATED_AT = "2026년 7월 4일";

export default function PrivacyPage() {
  return (
    <section className="page privacy-page">
      <h2 className="page-title">개인정보 안내</h2>
      <p className="page-desc">
        인사이트 오라클은 사주 계산과 리딩 생성을 위해 필요한 정보만 사용하고, 생년월일 원본을 AI 문장 생성 요청에
        직접 보내지 않도록 설계되어 있습니다.
      </p>

      <section className="card privacy-section">
        <h3 className="card-title">요약</h3>
        <ul className="reading-bullets">
          <li>생년월일시는 브라우저에서 사주 원국을 계산하는 데 사용됩니다.</li>
          <li>AI 해석 요청에는 생년월일 원본 대신 계산된 사주 정보와 사용자가 입력한 질문이 전송됩니다.</li>
          <li>리딩 기록은 자동 저장되지 않으며, 사용자가 저장을 선택한 경우에만 브라우저 저장소에 보관됩니다.</li>
          <li>PDF, 마크다운, 이미지 ZIP 저장은 사용자의 기기에서 생성됩니다.</li>
        </ul>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">처리하는 정보와 목적</h3>
        <div className="privacy-table-wrap">
          <table className="privacy-table">
            <thead>
              <tr>
                <th>정보</th>
                <th>사용 목적</th>
                <th>저장 위치</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>이름</td>
                <td>결과지와 저장 파일 표시</td>
                <td>사용자 기기</td>
              </tr>
              <tr>
                <td>생년월일시, 성별, 달력 유형, 출생지</td>
                <td>사주 원국, 대운, 세운, 월운 계산</td>
                <td>사용자 기기</td>
              </tr>
              <tr>
                <td>질문, 선택한 리딩 톤, 관심사</td>
                <td>AI 리딩 문장 생성과 개인화</td>
                <td>사용자 기기 및 AI 요청 본문</td>
              </tr>
              <tr>
                <td>계산된 사주 정보, 타로 카드 정보</td>
                <td>AI 리딩 문장 생성의 근거</td>
                <td>사용자 기기 및 AI 요청 본문</td>
              </tr>
              <tr>
                <td>리딩 결과, 후속 질문, 피드백</td>
                <td>사용자가 저장을 선택한 경우 기록 보기, 비교, 즐겨찾기, 설명 방식 개선</td>
                <td>사용자가 저장을 선택한 경우 사용자 기기</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">외부 AI 사용</h3>
        <p>
          리딩 문장을 생성할 때 외부 AI API를 사용할 수 있습니다. 현재 배포 환경에서는 Anthropic API가 사용되며,
          이 과정에서 계산된 사주 정보, 타로 카드 정보, 질문, 선택한 말투와 관심사 등이 전송될 수 있습니다.
        </p>
        <p>
          생년월일 원본은 AI 문장 생성 요청에 직접 보내지 않도록 설계되어 있지만, 계산된 사주 원국과 운 흐름은 개인을
          추정할 수 있는 민감한 맥락이 될 수 있으므로 필요한 범위에서만 사용합니다.
        </p>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">보관과 삭제</h3>
        <ul className="reading-bullets">
          <li>리딩 결과는 자동 저장되지 않습니다.</li>
          <li>사용자가 결과 화면에서 저장을 선택한 리딩만 브라우저 저장소에 보관됩니다.</li>
          <li>같은 기기와 같은 브라우저를 사용하는 경우 저장한 리딩을 기록 페이지에서 다시 볼 수 있습니다.</li>
          <li>기록 페이지에서 개별 리딩을 삭제하거나 전체 기록을 삭제할 수 있습니다.</li>
          <li>브라우저 데이터 삭제 또는 시크릿 모드 종료 시 저장 기록이 사라질 수 있습니다.</li>
        </ul>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">이용자 권리</h3>
        <p>
          사용자는 리딩 저장 여부를 선택할 수 있고, 저장한 리딩은 기록 페이지에서 삭제할 수 있습니다. 브라우저 저장소를
          삭제해 저장된 정보를 지울 수도 있습니다. 현재 앱은 별도 회원 가입 없이 동작하므로 서버 계정 기반 조회·수정
          기능은 제공하지 않습니다.
        </p>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">주의 사항</h3>
        <ul className="reading-bullets">
          <li>의학, 법률, 투자, 결혼, 이직 등 중대한 결정은 전문가 상담과 현실 자료를 함께 확인하세요.</li>
          <li>다른 사람의 생년월일을 입력할 때는 당사자의 동의를 받는 것이 좋습니다.</li>
          <li>서비스 구조나 외부 API 제공자가 변경되면 이 안내도 함께 수정되어야 합니다.</li>
        </ul>
      </section>

      <section className="card privacy-section">
        <h3 className="card-title">오픈소스 사용 고지</h3>
        <p>
          사주 만세력(음력·양력 변환) 계산에 오픈소스 라이브러리 lunar-javascript(© 2018 6tail, MIT License)를
          사용합니다.
        </p>
      </section>

      <p className="privacy-updated">마지막 수정일: {UPDATED_AT}</p>
      <Link to="/" className="btn btn--ghost">
        홈으로 돌아가기
      </Link>
    </section>
  );
}
