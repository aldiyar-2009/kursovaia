import { authenticateAndFetchLmsData } from '../services/lmsService.js';

export async function loginLms(req, res) {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({
        success: false,
        error: 'Укажите логин и пароль от аккаунта LMS Astana IT University.',
      });
    }

    const result = await authenticateAndFetchLmsData(username, password);
    return res.json(result);
  } catch (err) {
    return res.status(401).json({
      success: false,
      error: err.message || 'Ошибка авторизации в LMS AITU.',
    });
  }
}
