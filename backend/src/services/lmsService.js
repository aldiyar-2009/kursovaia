const LMS_BASE_URL = 'https://lms.astanait.edu.kz';

export async function authenticateAndFetchLmsData(username, password) {
  // Step 1: Get initial login page to retrieve logintoken and session cookie
  const initialRes = await fetch(`${LMS_BASE_URL}/login/index.php`, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  });

  const initialHtml = await initialRes.text();
  const tokenMatch = initialHtml.match(/name="logintoken" value="([^"]+)"/);
  if (!tokenMatch) {
    throw new Error('Не удалось получить токен авторизации LMS AITU. Портал временно недоступен.');
  }

  const loginToken = tokenMatch[1];
  const initialCookies = initialRes.headers.getSetCookie 
    ? initialRes.headers.getSetCookie() 
    : [initialRes.headers.get('set-cookie') || ''];

  let moodleSession = '';
  for (const c of initialCookies) {
    const match = c.match(/MoodleSession=([^;]+)/);
    if (match) {
      moodleSession = match[1];
      break;
    }
  }

  // Step 2: Submit login credentials
  const formParams = new URLSearchParams({
    anchor: '',
    logintoken: loginToken,
    username: username.trim(),
    password: password,
  });

  const loginRes = await fetch(`${LMS_BASE_URL}/login/index.php`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Cookie': moodleSession ? `MoodleSession=${moodleSession}` : '',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    body: formParams.toString(),
    redirect: 'manual', // do not auto follow to capture redirect cookie
  });

  const loginCookies = loginRes.headers.getSetCookie 
    ? loginRes.headers.getSetCookie() 
    : [loginRes.headers.get('set-cookie') || ''];

  for (const c of loginCookies) {
    const match = c.match(/MoodleSession=([^;]+)/);
    if (match) {
      moodleSession = match[1];
      break;
    }
  }

  const loginHtml = await loginRes.text();
  if (
    loginRes.status === 200 && (loginHtml.includes('id="login"') || loginHtml.includes('class="loginform"') || loginHtml.includes('Invalid login') || loginHtml.includes('Неверный логин'))
  ) {
    throw new Error('Неверный логин или пароль от аккаунта LMS Astana IT University.');
  }

  const authCookieHeader = `MoodleSession=${moodleSession}`;

  // Step 3: Fetch Profile, Grades and Calendar in parallel
  const [profileRes, gradesRes, calendarRes] = await Promise.all([
    fetch(`${LMS_BASE_URL}/user/profile.php`, { headers: { 'Cookie': authCookieHeader }, redirect: 'follow' }),
    fetch(`${LMS_BASE_URL}/grade/report/overview/index.php`, { headers: { 'Cookie': authCookieHeader }, redirect: 'follow' }),
    fetch(`${LMS_BASE_URL}/calendar/view.php?view=month`, { headers: { 'Cookie': authCookieHeader }, redirect: 'follow' }),
  ]);

  const profileHtml = await profileRes.text();
  const gradesHtml = await gradesRes.text();
  const calendarHtml = await calendarRes.text();

  if (profileRes.url.includes('login') || profileHtml.includes('id="page-login-index"') || profileHtml.includes('loginform')) {
    throw new Error('Неверный логин или пароль от аккаунта LMS Astana IT University.');
  }

  // Parse Student Profile
  let studentName = 'Студент AITU';
  const nameMatch = profileHtml.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  if (nameMatch) {
    studentName = nameMatch[1].replace(/<[^>]+>/g, '').trim();
  }

  let studentEmail = '';
  const emailMatch = profileHtml.match(/mailto:([^"]+)/i);
  if (emailMatch) {
    studentEmail = emailMatch[1].trim();
  }

  // Parse Courses and Grades
  const courses = [];
  const rows = gradesHtml.match(/<tr[\s\S]*?<\/tr>/gi) || [];
  for (const r of rows) {
    const cells = r.match(/<t[dh][\s\S]*?<\/t[dh]>/gi) || [];
    if (cells.length >= 2) {
      const courseRaw = cells[0].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
      const gradeRaw = cells[1].replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();

      if (courseRaw && !courseRaw.toLowerCase().includes('название курса') && !courseRaw.toLowerCase().includes('course name')) {
        let title = courseRaw;
        let teacher = 'Преподаватель AITU';

        if (courseRaw.includes('|')) {
          const parts = courseRaw.split('|');
          title = parts[0].trim();
          teacher = parts[1].trim();
        }

        const numericGrade = parseFloat(gradeRaw.replace(',', '.')) || 0.0;
        courses.push({
          id: `course_${courses.length + 1}`,
          title,
          teacher,
          grade: numericGrade,
        });
      }
    }
  }

  // Parse Calendar Events and Assignments
  const calendarEvents = [];
  const calDays = calendarHtml.match(/<td[^>]*class="[^"]*day[^"]*"[^>]*>[\s\S]*?<\/td>/gi) || [];
  for (const d of calDays) {
    if (d.includes('event')) {
      const text = d.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
      // Extract event summary line
      if (text.length > 5) {
        calendarEvents.push({
          id: `event_${calendarEvents.length + 1}`,
          summary: text,
        });
      }
    }
  }

  return {
    success: true,
    student: {
      name: studentName,
      email: studentEmail,
      username: username,
    },
    courses,
    calendarEvents,
  };
}
