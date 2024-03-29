---Exemplo 2 de uso do NCLua HTTP
package.path = package.path .. ';../?.lua'

local ncluahttp = require "ncluahttp"

---Função chamada quando a resposta da requisição é obtida
--@param header String contndo as informações do header da resposta.
--@param body String contendo as informações do corpo da mensagem (o conteúdo da mesma). 
function callback(header, body)
    if body then
       print("\n\n\n-------------------", body, "\n\n\n")
    end
    
  --Finaliza o script lua. Um link no NCL finalizará a aplicação NCL quando o nó lua for finalizado
  event.post {class="ncl", type="presentation", action="stop"}    
end

--Envia uma requisição HTTP. Quando o retorno for obtido, a função callback
--será executada assíncronamente. Tal função será chamada
--internamente pelo NCLua HTTP e receberá como parâmetro o header
--e o conteúdo (body) da resposta da requisição 
--Caso a porta seja diferente da padrão (80), a mesma pode ser indicada diretamente na URL,
--no formato http://url:porta
ncluahttp.request("http://manoelcampos.com/arquivos/pagina.html", callback)

