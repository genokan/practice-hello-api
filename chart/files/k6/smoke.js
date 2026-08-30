import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = __ENV.TARGET_URL || "http://hello-api-staging-hello-api";

export const options = {
  vus: 2,
  duration: "30s",
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<500"],
  },
};

export default function () {
  const response = http.get(`${targetUrl}/work`, { tags: { profile: "smoke" } });

  check(response, {
    "work returned 200": (result) => result.status === 200,
  });

  sleep(1);
}
