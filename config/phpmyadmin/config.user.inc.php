<?php
// Ajustes do phpMyAdmin para os estagiários
// Sempre em português, mesmo com o navegador em inglês
$cfg['Lang'] = 'pt_BR';
// Esconde os bancos de sistema da lista lateral (o estagiário não mexe neles)
$cfg['Servers'][1]['hide_db'] = '^(information_schema|performance_schema|mysql|sys)$';
// Sem aviso de versão nova: quem atualiza é o administrador
$cfg['VersionCheck'] = false;
