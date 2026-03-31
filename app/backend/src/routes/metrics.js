const express = require('express');
const router = express.Router();

router.get('/', async (req, res) => {
  try {
    const register = req.app.locals.metricsRegistry;
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

module.exports = router;
