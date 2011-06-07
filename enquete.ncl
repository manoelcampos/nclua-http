<?xml version="1.0" encoding="ISO-8859-1"?>
<ncl id="enquete" xmlns="http://www.ncl.org.br/NCL3.0/EDTVProfile">
	<head>
		<transitionBase>
			<transition id="tFade" type="fade" dur="0.7" />			
		</transitionBase>
		
		  
		<regionBase>
			<region id="rgTela" width="100%" height="100%">
				<region id="rgLua" width="100%" height="40%" left="0" top="60%" zIndex="1" />
			</region>
		</regionBase>
		
		<descriptorBase>
			<descriptor id="dLua" region="rgLua" focusIndex="luaIdx" />
		</descriptorBase>

	</head>

	<body>
		<port id="pInicio" component="lua"/>
		
		<media type="application/x-ginga-settings" id="programSettings">
	        <property name="service.currentKeyMaster" value="luaIdx"/>
		</media>
		
		<media id="lua" src="enquete.lua" descriptor="dLua">
		</media>
	</body>
</ncl>

