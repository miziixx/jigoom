import { beforeEach, describe, expect, it } from "vitest";
import { activateProfile, activeProfileId, deleteProfileFromList, loadProfileList, saveProfileToList } from "./profileList.js";
import { loadProfile } from "./profile.js";
import type { BirthInfo } from "../types";

function installMemoryLocalStorage() {
  const store = new Map<string, string>();
  const mock = {
    getItem: (k: string) => (store.has(k) ? store.get(k)! : null),
    setItem: (k: string, v: string) => void store.set(k, v),
    removeItem: (k: string) => void store.delete(k),
    clear: () => store.clear(),
    key: (i: number) => Array.from(store.keys())[i] ?? null,
    get length() {
      return store.size;
    },
  };
  (globalThis as unknown as { localStorage: typeof mock }).localStorage = mock;
}

const me: BirthInfo = { calendarType: "solar", year: 1990, month: 12, day: 23, hour: 8, minute: 0, gender: "female" };
const mom: BirthInfo = { calendarType: "solar", year: 1965, month: 3, day: 2, hour: 14, minute: 30, gender: "female", displayName: "엄마" };

describe("profileList (C-4 사이드바 — 저장된 사주 전환)", () => {
  beforeEach(() => {
    installMemoryLocalStorage();
    localStorage.clear();
  });

  it("빈 상태에서는 목록이 없다", () => {
    expect(loadProfileList()).toEqual([]);
  });

  it("프로필을 저장하면 목록 맨 앞에 쌓이고, 이름이 없으면 날짜로 라벨을 만든다", () => {
    saveProfileToList(me);
    saveProfileToList(mom);
    const list = loadProfileList();
    expect(list).toHaveLength(2);
    expect(list[0].label).toBe("엄마");
    expect(list[1].label).toBe("1990-12-23");
  });

  it("같은 명식을 다시 저장하면 새로 추가하지 않고 기존 항목을 갱신한다", () => {
    saveProfileToList(me);
    saveProfileToList(me, "새 이름");
    const list = loadProfileList();
    expect(list).toHaveLength(1);
    expect(list[0].label).toBe("새 이름");
  });

  it("activateProfile은 기존 profile.ts의 saveProfile을 그대로 재사용해 '현재 프로필'을 바꾼다", () => {
    const saved = saveProfileToList(mom);
    expect(loadProfile()).toBeNull();
    activateProfile(saved.id);
    expect(loadProfile()).toEqual(mom);
  });

  it("activeProfileId는 지금 현재 프로필과 같은 명식의 목록 항목 id를 돌려준다", () => {
    const saved = saveProfileToList(mom);
    expect(activeProfileId()).toBeNull();
    activateProfile(saved.id);
    expect(activeProfileId()).toBe(saved.id);
  });

  it("삭제하면 목록에서 빠진다", () => {
    const saved = saveProfileToList(me);
    saveProfileToList(mom);
    deleteProfileFromList(saved.id);
    expect(loadProfileList()).toHaveLength(1);
    expect(loadProfileList()[0].label).toBe("엄마");
  });
});
