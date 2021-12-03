---Exemplo de enquete usando NCLua HTTP
package.path = package.path .. ';../?.lua'

require "ncluahttp"

---Mostra mensagem indicando que a requisição está sendo enviada
function showSending()
  canvas:attrFont("vera", 28)
  local w, h = canvas:attrSize()
  canvas:attrColor("silver")
  canvas:drawRect("fill", 0, 0, w, h)
  canvas:attrColor("white")
  canvas:drawText(4,4, "Enviando requisição. Por favor aguarde...")
  canvas:flush()
end

---Função chamada quando a resposta da requisição é obtida
--@param header String contndo as informações do header da resposta.
--@param body String contendo as informações do corpo da mensagem (o conteúdo da mesma). 
function callback(header, body)
  print("Resposta obtida\n", header..body, "\n\n\n")

  local w, h = canvas:attrSize()
  canvas:attrColor("silver")
  canvas:drawRect("fill", 0, 0, w, h)
  canvas:attrColor("white")
  canvas:drawText(4,4, body)
  canvas:flush()
end

showSending()

local url = "http://manoelcampos.com/votacao/enquete.php?voto=sim"
ncluahttp.request(url, callback)

