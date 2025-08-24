const express = require('express');
const app = express();
app.use(express.json());
app.get('/health', (_req,res)=>res.json({status:'stub', ready:false}));
app.post('/api/session/create', (_req,res)=>res.json({sessionId:'stub-session', instructions:'Provide real whatsapp-auth.js'}));
app.get('/api/session/:id/status', (req,res)=>res.json({sessionId:req.params.id, authenticated:false, ready:false, status:'stub'}));
app.post('/api/session/:id/send', (_req,res)=>res.status(501).json({error:'Not implemented in stub'}));
app.listen(process.env.PORT||3002, ()=>console.log('Stub WhatsApp server on',process.env.PORT||3002));
