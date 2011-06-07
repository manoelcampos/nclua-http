---Módulo para realização de conexões TCP. 
--Utiliza co-rotinas de lua para simular multi-thread.
--Fonte: <a href="http://www.telemidia.puc-rio.br/~francisco/nclua/index.html">Tutorial de NCLua</a>
--@class module

-- TODO:
-- * nao aceita `tcp.execute` reentrante

--Declara localmente módulos e funçõe globais pois, ao definir
--o script como um módulo, o acesso ao ambiente global é perdido
local _G, coroutine, event, assert, pairs, type, print
    = _G, coroutine, event, assert, pairs, type, print
local s_sub = string.sub

module 'tcp'

---Lista de conexões TCP ativas
local CONNECTIONS = {}

---Obtém a co-rotina em execução
--@returns Retorna o identificador da co-rotina em execução
local current = function ()
    return assert(CONNECTIONS[assert(coroutine.running())])
end

---(Re)Inicia a execução de uma co-rotinas. Estas, são criadas
--suspensas, assim, é necessário resumí-las para entrarem
--em execução.
--@param co Co-rotina a ser resumida
--@param ... Todos os parâmetros adicionais
--são passados à função que a co-rotina executa.
--Quando a co-rotina é suspensa com yield, ao ser resumida
--novamente, estes parâmetros extras passados na chamada de resume
--são retornados pela yield. Isto é usado, por exemplo, na co-rotina da
--função receive, para receber a resposta de uma requisição TCP. Assim,
--ao iniciar, co-rotina da função é suspensa para que fique aguardando
--a resposta da requisição TCP. Quando a função tratadora de eventos (handler)
--recebe os dados, ela resume a co-rotina da função receive. Os dados
--recebidos são passados à função resume, e estes são retornados pela função
--yield depois que a co-rotina é reiniciada.
local resume = function (co, ...)
    assert(coroutine.status(co) == 'suspended')
    assert(coroutine.resume(co, ...))
    if coroutine.status(co) == 'dead' then
       CONNECTIONS[co] = nil
    end
end

---Função tratadora de eventos. Utilizada para tratar 
--os eventos gerados pelas chamadas às funções da classe tcp.
--@param evt Tabela contendo os dados do evento capturado
function handler (evt)
    if evt.class ~= 'tcp' then return end

    if evt.type == 'connect' then
        for co, t in pairs(CONNECTIONS) do
            if (t.waiting == 'connect') and
               (t.host == evt.host) and (t.port == evt.port) then
                t.connection = evt.connection
                t.waiting = nil
                --Continua a execução da co-rotina,
                --fazendo com que a função connect, que causou
                --o disparo do evento connect, capturado
                --por esta função (handler), seja finalizada.
                resume(co) 
                break
            end
        end
        return
    end

    if evt.type == 'disconnect' then
        for co, t in pairs(CONNECTIONS) do
            if t.waiting and
               (t.connection == evt.connection) then
                t.waiting = nil
                resume(co, nil, 'disconnected')
            end
        end
        return
    end

	--Evento disparado quando existem dados a serem recebidos,
	--após a chamada da função send (para enviar uma requisição)
  --e a chamada subsequente da função receive.
    if evt.type == 'data' then
        for co, t in pairs(CONNECTIONS) do
            if (t.waiting == 'data') and
            (t.connection == evt.connection) then
                --O atributo value da tabela evt contém os dados
                --recebidos. Assim, continua a execução da função que disparou
                --este evento (função receive). O valor de evt.value
                --é retornado pela função coroutine.yield, chamada
                --dentro da função receive (que ficou suspensa
                --aguardando os dados serem recebidos).
                --Desta forma, dentro da função receive, o retorno
                --de coroutine.yield contém os dados recebidos.
                resume(co, evt.value)
            end
        end
        return
    end
end
event.register(handler)



---Função que deve ser chamada para iniciar uma conexão TCP.
--@param f Função que deverá executar as rotinas
--para realização de uma conexão TCP, envio de requisições
--e obtenção de resposta.   
--@param ... Todos os parâmetros adicionais 
--são passados à função que a co-rotina executa.
--@see resume
function execute (f, ...)
    resume(coroutine.create(f), ...)
end

---Conecta em um servidor por meio do protocolo TCP.
--A função só retorna quando a conexão for estabelecida.
--@param host Nome do host para conectar
--@param port Porta a ser usada para a conexão
function connect (host, port)
    local t = {
        host    = host,
        port    = port,
        waiting = 'connect'
    }
    CONNECTIONS[coroutine.running()] = t

    event.post {
        class = 'tcp',
        type  = 'connect',
        host  = host,
        port  = port,
    }
    
    --Suspende a execução da co-rotina.
    --A função atual (connect) só retorna quando
    --a co-rotina for resumida, o que ocorre
    --quando o evento connect é capturado
    --pela função handler. 
    return coroutine.yield() 
end

---Fecha a conexão TCP e retorna imediatamente
function disconnect ()
    local t = current()
    event.post {
        class      = 'tcp',
        type       = 'disconnect',
        connection = assert(t.connection),
    }
end

---Envia uma requisição TCP ao servidor no qual se está conectado, e retorna imediatamente.
--@param value Mensagem a ser enviada ao servidor.
function send (value)
    local t = current()
    event.post {
        class      = 'tcp',
        type       = 'data',
        connection = assert(t.connection),
        value      = value,
    }
end


---Recebe resposta de uma requisição enviada previamente
--ao servidor.
--@param pattern Padrão para recebimento dos dados.
--Se passado *a, todos os dados da resposta são 
--retornados de uma só vez, sem precisar fazer
--chamadas sucessivas a esta função.
--Se omitido, os dados vão sendo retornados parcialmente,
--sendo necessárias várias chamadas à função.  
function receive (pattern)
    pattern = pattern or '' -- TODO: '*l'/number
    local t = current()
    t.waiting = 'data'
    t.pattern = pattern
    
    if s_sub(pattern, 1, 2) ~= '*a' then
        --Suspende a execução da função, até que
        --um bloco de dados seja recebido.
        --Ela só é resumida depois que 
        --a função handler (tratadora de eventos)
        --receber um bloco de dados. Nesse momento,
        --a função receive retorna o bloco de dados.   
        --Tendo entrado neste if, o parâmetro pattern será
        --diferente de '*a', logo, serão necessárias
        --várias chamadas sucessívas a receive para obter
        --toda a resposta da requisição enviada previamente
        --por meio da função send.
        --A função receive retorna nil quando não houver
        --mais nada para ser retornado.
        return coroutine.yield()
    end
    
    --Chegando aqui, é porque o parâmetro pattern é igual
    --a '*a', indicando que a função só deve retornar depois
    --que toda a resposta da requisição enviada previamente,
    --por meio da função send, tiver sido retornada.
    local all = ''
    while true do
        --Suspende a execução da função, até que
        --um bloco de dados seja recebido.
        --Ela só é resumida depois que 
        --a função handler (tratadora de eventos)
        --receber um bloco de dados. Nesse momento,
        --a função receive retorna o bloco de dados.   
        --Se o resultado for nil, a função finaliza 
        --devolvendo todos os blocos de resposta recebidos,
        --concatenados. Não sendo nil, a função suspende a execução
        --até receber novo bloco.
        local ret = coroutine.yield()
        if ret then
            all = all .. ret
        else
            return all
        end
    end
end
