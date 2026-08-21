import * as types from "./types";
const TOKEN = localStorage.getItem("token");
const initialState = {
  userLogin: { loading: false, error: false, message: "" },
  userLogout: { message: "" },
  data: {
    isAuthenticated: !!TOKEN,
    token: TOKEN,
    user: null,
  },
};
export default function authReducer(state = initialState, { type, payload }) {
  switch (type) {
    // SonarQube bug fix (javascript:S128 — "case A || B || C" fallthrough):
    // `case X || Y || Z:` does NOT mean "match X, Y, or Z". The `||` runs
    // BEFORE the switch compares anything, and short-circuits to just its
    // first truthy operand — so this line was silently equivalent to
    // `case types.LOGIN_PATIENT_REQUEST:` alone; LOGIN_ADMIN_REQUEST and
    // LOGIN_DOCTOR_REQUEST never actually matched here. That's exactly why
    // near-duplicate standalone `case types.LOGIN_DOCTOR_REQUEST:` /
    // `LOGIN_ADMIN_REQUEST:` blocks existed further down this switch (a
    // workaround for this same bug) — consolidated below via real
    // fall-through (stacked `case` labels, no code between them), and the
    // redundant duplicate blocks removed.
    case types.LOGIN_PATIENT_REQUEST:
    case types.LOGIN_ADMIN_REQUEST:
    case types.LOGIN_DOCTOR_REQUEST:
      return {
        ...state,
        userLogin: { loading: true, error: false },
      };
    case types.LOGIN_PATIENT_SUCCESS:
    case types.LOGIN_ADMIN_SUCCESS:
    case types.LOGIN_DOCTOR_SUCCESS:
      localStorage.setItem("token", payload.token);
      return {
        ...state,
        userLogin: { loading: false, error: false, message: payload.message },
        data: {
          isAuthenticated: payload.token ? true : false,
          token: payload.token,
          user: payload.user,
        },
      };
    case types.EDIT_DOCTOR_REQUEST:
      return {
        ...state,
        data: {
          isAuthenticated: true,
          token: null,
          user: null,
        },
      };
    case types.EDIT_PATIENT_REQUEST:
      return {
        ...state,
        data: {
          isAuthenticated: true,
          token: null,
          user: null,
        },
      };
    case types.EDIT_ADMIN_REQUEST:
      return {
        ...state,
        data: {
          isAuthenticated: true,
          token: null,
          user: null,
        },
      };
    case types.LOGIN_PATIENT_ERROR:
    case types.LOGIN_ADMIN_ERROR:
    case types.LOGIN_DOCTOR_ERROR:
      return {
        ...state,
        userLogin: { loading: false, error: true, message: payload.message },
      };
    case types.EDIT_DOCTOR_SUCCESS:
      return {
        ...state,
        data: {
          isAuthenticated: payload.token ? true : false,
          token: payload.token,
          user: payload.user,
        },
      };
    case types.EDIT_PATIENT_SUCCESS:
      return {
        ...state,
        data: {
          isAuthenticated: payload.token ? true : false,
          token: payload.token,
          user: payload.user,
        },
      };
    case types.EDIT_ADMIN_SUCCESS:
      return {
        ...state,
        data: {
          isAuthenticated: payload.token ? true : false,
          token: payload.token,
          user: payload.user,
        },
      };

    case "AUTH_LOGIN_RESET":
      return {
        ...state,
        userLogin: { loading: false, error: false, message: "" },
      };
    case types.AUTH_LOGOUT:
      localStorage.removeItem("token");
      return {
        ...state,
        userLogin: { loading: false, error: false, message: "" },
        userLogout: { message: "Logout Successfully" },
        data: {
          isAuthenticated: false,
          token: null,
          user: null,
        },
      };
    default:
      return state;
  }
}