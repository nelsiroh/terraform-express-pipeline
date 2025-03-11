import http from 'k6/http';
import { sleep } from 'k6';

export let options = {
    stages: [
        { duration: '2m', target: 100 },  // Ramp-up to 100 users
        { duration: '5m', target: 100 },  // Stay at 100 users
        { duration: '2m', target: 0 },    // Ramp-down
    ],
};

export default function () {
    http.get('http://localhost:3000/api/health');
    sleep(1);
}
