<?

/*
Sistema de enquete para TV Digital. 
Desenvolvido por Manoel Campos da Silva Filho
Mestrando em Engenharia Elétrica pela UnB na área de TV Digital
http://manoelcampos.com
manoelcampos@gmail.com

Créditos
Biblioteca tcp.lua: http://www.telemidia.puc-rio.br/~francisco/nclua/index.html 
*/

  define("SIM", "sim.txt");
  define("NAO", "nao.txt");
  
  function lerArquivo($fileName) {
     if(!file_exists($fileName))
        return 0;
        
     if($arq = fopen($fileName, "r+")) {
        $votos = fgets($arq, 100);
        fclose($arq);
        return $votos;
     }  
     return 0;
  }
  
  function registrarVoto($fileName) {
     $votos = lerArquivo($fileName);
     $votos++;
     if($arq = fopen($fileName, "w+")) {
        fwrite($arq, $votos);
        fclose($arq);
     }
     return $votos;  
  }
  
  function exibeVotos() {
     $votos = lerArquivo(SIM);
     print("Sim: $votos<br/>");
     
     $votos = lerArquivo(NAO);
     print("N&atilde;o: $votos<br/>");  
  }
  
  //Gera tabela lua contendo os dados a serem utilizados
  //pela aplicação NCLua de TV Digital
  function geraTableVotos() {
     $votos = lerArquivo(SIM);
     print("votos = { \n");
     print(" sim = $votos,  \n");
     
     $votos = lerArquivo(NAO);
     print(" nao = $votos,  \n");
     print(" url = 'http://manoelcampos.com' \n");
     print("}\n");  
  }  
  
  //---------------------------------------------------
  
  if(isset($_REQUEST["voto"])) {  
	 $voto = strtolower($_REQUEST["voto"]);
	 if($voto == "sim" or $voto == "s") 
	    $fileName = SIM;
	 else $fileName = NAO;
	 
	 registrarVoto($fileName);
	 geraTableVotos();
  }
  else exibeVotos();
?>
