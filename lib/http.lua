---NCLua HTTP v0.9.9.1: Módulo para envio e recebimento de requisições HTTP em aplicações NCLua para TV Digital,
--possibilitando também, o download de arquivos por meio de tal protocolo.<br/>
--Utiliza a classe tcp disponibilizada no
-- <a href="http://www.telemidia.puc-rio.br/~francisco/nclua/tutorial/index.html">Tutorial de NCLua</a>
-- e o módulo de conversão de/para base64 disponível em <a href="http://lua-users.org/wiki/BaseSixtyFour">Lua Users</a><p/>
--@licence: <a href="http://creativecommons.org/licenses/by-nc-sa/2.5/br/">http://creativecommons.org/licenses/by-nc-sa/2.5/br/</a>
--@author Manoel Campos da Silva Filho<br/>
--Professor do Instituto Federal de Educação, Ciência e Tecnologia do Tocantins<br/>
--Mestrando em Engenharia Elétrica na Universidade de Brasília, na área de TV Digital<br/>
--<a href="http://manoelcampos.com">http://manoelcampos.com</a>
--@class module
--<p/>

require "tcp"
require "base64"
require "util"

local _G, tcp, print, util, base64, string, coroutine, table, type = 
      _G, tcp, print, util, base64, string, coroutine, table, type

module "http"

version = "NCLuaHTTP/0.9.9"

---Separa o header do body de uma resposta a uma requisição HTTP
--@param response String contendo a resposta a uma requisição HTTP
--@return Retorna o header e o body da resposta da requisição
local function getHeaderAndContent(response)
    --Procura duas quebras de linha consecutivas, que separam
    --o header do body da resposta
	local i = string.find(response, string.char(13,10,13,10))
	local header, body = "", ""
	if i then
	   header = string.sub(response, 1, i)
	   body = string.sub(response, i+4, #response)
	else 
	   header = response
	end
	return header, body
end

---Envia uma requisição HTTP para um determinado servidor
--@param url URL para a página que deseja-se acessar. A mesma pode incluir um número de porta,
--não necessitando usar o parâmetro port.
--@param callback Função de callback a ser executada quando
--a resposta da requisição for obtida. A mesma deve possuir
--em sua assinatura, um parâmetro header e um body, que conterão, 
--respectivamente, os headers retornados e o corpo da resposta
--(os dois como strings).
--@param method Método HTTP a ser usado: GET ou POST. Se omitido, é usado GET.
--onde a requisição deve ser enviada
--@param params String com o conteúdo a ser adicionado à requisição,
--ou uma tabela, contendo pares de paramName=value,
--no caso de requisições post enviando campos de formulário. 
--Deve estar no formato URL Encode. 
--No caso de requisições GET, os parâmetros devem ser passados 
--diretamente na URL. Opcional
--@param userAgent Nome da aplicação/versão que está enviando a requisição. Opcional
--@param headers Headers HTTP adicionais a serem incluídos na requisição. Opcional
--@param user Usuário para autenticação básica. Opcional
--@param password Senha para autenticação básição. Opcional
--@param port Porta a ser utilizada para a conexão. O padrão é 80, no caso do valor ser omitido.
--A porta também pode ser especificada diretamente na URL. Se for indicada uma porta lá e aqui
--no parâmetro port, a porta da url é que será utilizada e a do parâmetro port será ignorada.
function request(url, callback, method, params, userAgent, headers, user, password, port)
    headers = headers or ""
    params = params or ""
    if method == nil or method == "" then
       method = "GET"
    end
    userAgent = userAgent or version
		port = port or 80
    method = string.upper(method)
    if method ~= "GET" and method ~= "POST" then
       error("Parâmetro method deve ser GET ou POST")
    end
    
    local co = false
    local protocol, host, port1, path = splitUrl(url)
    --Se existir uma número de porta dentro da URL, o valor do parâmetro port é ignorado e 
    --recebe a porta contida na URL.
    if port1 ~= "" then
       port = port1
    end
    if protocol == "" then
       protocol = "http://"
       url = protocol .. url
    end
    
    function sendRequest()
	    tcp.execute(
	        function ()
	            tcp.connect(host, port)
	            --conecta no servidor
	            print("Conectado a "..host.." pela porta " .. port)
	            
				  		--Troca espaços na URL por %20
	            url = string.gsub(url, " ", "%%20")
	            local request = {}
				local fullUrl = ""
				if port == 80 then
				   fullUrl = url
				else
				   fullUrl = protocol .. host .. ":" ..port .. path
				end
              --TODO: O uso de HTTP/1.1 tava fazendo com que a app congelasse 
              --ao tentar obter toda resposta de uma requisição.
              --No entanto, pelo q sei, o cabeçalho Host: usado abaixo
              --é específico de HTTP 1.1, mas isto não causou problema.
	            table.insert(request, method .." "..fullUrl.." HTTP/1.0")
	            
	            if userAgent and userAgent ~= "" then
	               table.insert(request, "User-Agent: " .. userAgent)
	            end
	               
	            if params ~= "" then
	               --Se params for uma tabela 
	               --é porque ela representa uma lista
	               --de campos a serem enviados via POST, logo
	               --adicione o content-type específico para este caso.
	               if (method=="POST") and (type(params) == "table") then
	                   if headers ~= "" then
	                      headers = headers .. "\n"
	                   end
	                   headers = headers.."Content-type: application/x-www-form-urlencoded"
	               end
	            end
	               
	            if headers ~= "" then
	               table.insert(request, headers)
	            end   
	            --O uso de Host na requisição é necessário
	            --para tratar redirecionamentos informados 
	            --pelo servidor (código HTTP como 301 e 302)
	            table.insert(request, "Host: "..host)
	            if user and password and user ~= "" and password ~= "" then
	               table.insert(request, "Authorization: Basic " .. 
	                     base64.enc(user..":"..password))
	            end
                if params ~= "" then
                   if type(params) == "table" then
                      params = util.urlEncode(params)
                   end
                   --length of the URL-encoded params data
                   table.insert(request, "Content-Length: " .. #params.."\n")
                   table.insert(request, params)
                end   	            
		        table.insert(request, "\n")
                --Pega a tabela contendo os dados da requisição HTTP e gera uma string para ser enviada ao servidor
			    local requestStr = table.concat(request, "\n")
	            print("\n--------------------Request: \n\n"..requestStr)
	            --envia uma requisição HTTP para obter o arquivo XML do feed RSS
	            tcp.send(requestStr)
	            --obtém todo o conteúdo do arquivo XML solicitado
	            local response = tcp.receive("*a") --parâmetro "*a" = receber todos os dados da requisição de uma vez só
	            --[[
	            if response ~= nil then
                   print("\n\n----------------------------Resposta da requisição obtida\n\n")
                   print(response)
  		        end--]]
		          
	            tcp.disconnect()
			    --print("\n--------------------------Desconectou")
	    	    coroutine.resume(co, response)        
	        end
	    )    
	    --print("\n--------------------------Saiu da body function")
    end
    
    local function startRequestProcess()
	    --print("\n--------------------------Iniciar co-rotina (resume)")
	    coroutine.resume(coroutine.create(sendRequest))
	    --print("\n--------------------------Terminou resume")
	    co = coroutine.running()
	    --print("\n--------------------------Co-rotina suspensa (yield)")
	    --Bloqueia o programa até obter o retorno da co-rotina
	    --(que retornará a resposta da requisição HTTP)
	    local response =  coroutine.yield()
	    --print("\n--------------------------Co-rotina finalizada (terminou yield)")
        if callback then
           callback(getHeaderAndContent(response))
	    end
    end
    
    util.coroutineCreate(startRequestProcess)
end

---Envia uma requisição HTTP para uma URL que represente um arquivo,
--e então faz o download do mesmo.
--@param url URL para a página que deseja-se acessar. A mesma pode incluir um número de porta,
--não necessitando usar o parâmetro port.
--@param callback Função de callback a ser executada quando
--a resposta da requisição for obtida. A mesma deve possuir
--em sua assinatura, um parâmetro header e um body, que conterão, 
--respectivamente, os headers retornados e o corpo da resposta
--(os dois como strings).
--@param fileName Caminho completo para salvar o arquivo localmente.
--Só deve ser usado para depuração, pois passando-se
--um nome de arquivo, fará com que a função use o módulo io,
--não disponível no Ginga. Para uso em ambientes
--reais (Set-top boxes), deve-se passar nil para o parâmetro
--@param userAgent Nome/versão do cliente http. Opcional
--@param user Usuário para autenticação básica. Opcional
--@param password Senha para autenticação básição. Opcional
--@param port Porta a ser utilizada para a conexão. O padrão é 80, no caso do valor ser omitido.
--A porta também pode ser especificada diretamente na URL. Se for indicada uma porta lá e aqui
--no parâmetro port, a porta da url é que será utilizada e a do parâmetro port será ignorada.
function getFile(url, callback, fileName, userAgent, user, password, port)
    local function fileDownloaded(header, body)
	    if header then
	       --print(response, "\n")
	       print("Dados da conexao TCP recebidos")
	       --Verifica se o código de retorno é OK
	       if string.find(header, "200 OK") then
	          if fileName then
	             util.createFile(body, fileName, true)
	             print('Arquivo criado com sucesso: '..fileName)
	          end
	       end
	    else
	       print("Erro ao receber dados da conexao TCP")
	    end
    
        if callback then
           callback(header, body)
        end
    end
    
    --(url, method, params, userAgent, headers, user, password)
    local header, body = request(url, fileDownloaded, "GET", nil, userAgent, nil, user, password, port)
end

---Obtém o valor de um determinado campo de uma resposta HTTP
--@param header Conteúdo do cabeçalho da resposta HTTP de onde deseja-se extrair
--o valor de um campo do cabeçalho
--@param fieldName Nome do campo no cabeçalho HTTP
function getHttpHeader(header, fieldName)
  --Procura a posição de início do campo
  local i = string.find(header, fieldName .. ":")
  --Se o campo existe
  if i then
     --procura onde o campo termina (pode terminar com \n ou espaço
     --a busca é feita a partir da posição onde o campo começa
     local fim = string.find(header, "\n", i) or string.find(header, " ", i)
     return string.sub(header, i, fim)
  else
     return nil
  end
end

---Obtém uma URL e divide a mesma em protocolo, host, porta e path
--@param url URL a ser dividida
--@return Retorna o protocolo, host, porta e o path obtidas da URL.
--Caso algum destes valores não exita na URL, é retornada uma string vazia no seu lugar.
function splitUrl(url)
  --TODO: O uso de expressões regulares seria ideal nesta função
  --por meio de string.gsub

  local protocolo = ""
  local separadorProtocolo = "://"
  --procura onde inicia o nome do servidor, que é depois do separadorProtocolo
  local i = string.find(url, separadorProtocolo)
  if i then 
     protocolo = string.sub(url, 1, i+2)
 	   --soma o tamanho do separadorProtocolo em i para pular o separadorProtocolo, 
     --que identifica o protocolo,
	   --e iniciar na primeira posição do nome do host
	   i=i+#separadorProtocolo
  else
     --se a URL não possui um protocolo, então o nome
     --do servidor inicia na primeira posição
     i = 1
  end

  local host, porta, path = "", "", ""
  --procura onde termina o nome do servidor, 
  --na primeira barra após o separadorProtocolo
  local j = string.find(url, "/", i)
  --se encontrou uma barra, copia o nome do servidor até a barra,
  --pois após ela, é o path
  if j then
     host = string.sub(url, i, j-1)
     path  = string.sub(url, j, #url)
  else
     --senão, não há um path após o nome do servidor, sendo o restante da url
     --o nome do servidor
     host = string.sub(url, i)
  end

  --verifica se há um número de porta dentro do host (a porta vem após os dois pointos)
  i = string.find(host, ":")
  if i then
    porta = string.sub(host, i+1, #host)
    host = string.sub(host, 1, i-1)
  end
  
  return protocolo, host, porta, path
end

