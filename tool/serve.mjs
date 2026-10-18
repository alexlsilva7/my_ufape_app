import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

// Same-origin API proxy for a separately built Flutter web client.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../build/web');
const port=Number(process.env.FLUTTER_PORT||8787);
const backend=new URL(process.env.API_PROXY_TARGET||'http://127.0.0.1:3000');
const types={'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.png':'image/png','.webp':'image/webp','.pdf':'application/pdf','.ttf':'font/ttf','.otf':'font/otf','.ico':'image/x-icon'};
const server=http.createServer(async(req,res)=>{
  const requestUrl=new URL(req.url,'http://localhost');
  if(requestUrl.pathname.startsWith('/api/')){
    try{
      const chunks=[];for await(const chunk of req)chunks.push(chunk);
      const headers={...req.headers};delete headers.host;delete headers.connection;
      const response=await fetch(new URL(req.url,backend),{method:req.method,headers,body:['GET','HEAD'].includes(req.method)?undefined:Buffer.concat(chunks),signal:AbortSignal.timeout(req.url.includes('extract')?1800000:30000)});
      res.statusCode=response.status;for(const name of ['content-type','retry-after','cache-control']){if(response.headers.has(name))res.setHeader(name,response.headers.get(name));}
      res.end(Buffer.from(await response.arrayBuffer()));
    }catch{res.writeHead(503,{'Content-Type':'application/json'});res.end(JSON.stringify({error:'API indisponível. Inicie o backend ou configure API_PROXY_TARGET.'}));}
    return;
  }
  const local=path.resolve(root,`.${decodeURIComponent(requestUrl.pathname)}`);
  if(local!==root&&!local.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
  const file=fs.existsSync(local)&&fs.statSync(local).isFile()?local:path.join(root,'index.html');
  if(!fs.existsSync(file)){res.writeHead(503);res.end('Execute fvm flutter build web primeiro.');return;}
  res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');res.setHeader('Cache-Control','no-cache');fs.createReadStream(file).pipe(res);
});
server.listen(port,'127.0.0.1',()=>console.log(`My UFAPE Flutter: http://127.0.0.1:${port} (API: ${backend.origin})`));
