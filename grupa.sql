--4. Realiza un trigger que cada vez que se inserte una puntuación menor de 5, informe de este hecho por correo electrónico al investigador responsable del experimento, incluyendo en el correo la fecha de la prueba, el aspecto valorado y donde vive el catador.

--INSTALACION DEL CLIENTE DE CORREO POSTFIX
oracle@so:~$ sudo apt-get update
oracle@so:~$ sudo apt-get install postfix

  ┌─────────────────────┤ Postfix Configuration ├──────────────────────┐
  │ Escoja el tipo de configuración del servidor de correo que se      │ 
  │ ajusta mejor a sus necesidades.                                    │ 
  │                                                                    │ 
  │  Sin configuración:                                                │ 
  │   Mantiene la configuración actual intacta.                        │ 
  │  Sitio de Internet:                                                │ 
  │   El correo se envía y recibe directamente utilizando SMTP.        │ 
  │  Internet con «smarthost»:                                         │ 
  │   El correo se recibe directamente utilizando SMTP o ejecutando    │ 
  │ una                                                                │ 
  │   herramienta como «fetchmail». El correo de salida se envía       │ 
  │ utilizando                                                         │ 
  │   un «smarthost».                                                  │ 
  │  Sólo correo local:                                                │ 
  │   El único correo que se entrega es para los usuarios locales. No  │ 
  │   hay red.                                                         │ 
  │                                                                    │ 
  │ Tipo genérico de configuración de correo:                          │ 
  │                                                                    │ 
  │                      Sin configuración                             │ 
  │                      Sitio de Internet                             │ 
  │                      Internet con «smarthost»                      │ 
  │                      Sistema satélite                              │ 
  │                      Sólo correo local                             │ 
  │                                                                    │ 
  │                                                                    │ 
  │                 <Aceptar>                <Cancelar>                │ 
  │                                                                    │ 
  └────────────────────────────────────────────────────────────────────┘ 

 ┌──────────────────────┤ Postfix Configuration ├──────────────────────┐
 │ El «nombre de sistema de correo» es el nombre del dominio que se    │ 
 │ utiliza para «cualificar» TODAS las direcciones de correo sin un  │ 
 │ nombre de dominio. Esto incluye el correo hacia y desde «root»:     │ 
 │ por favor, no haga que su máquina envíe los correo electrónicos     │ 
 │ desde root@example.org a menos que root@example.org se lo haya      │ 
 │ pedido.                                                             │ 
 │                                                                     │ 
 │ Otros programas utilizarán este nombre. Deberá ser un único nombre  │ 
 │ de dominio cualificado (FQDN).                                      │ 
 │                                                                     │ 
 │ Por consiguiente, si una dirección de correo en la máquina local    │ 
 │ es algo@example.org, el valor correcto para esta opción será        │ 
 │ example.org.                                                        │ 
 │                                                                     │ 
 │ Nombre del sistema de correo:                                       │ 
 │                                                                     │ 
 │ servidororacle.gonzalonazareno.org_____________ │ 
 │                                                                     │ 
 │                  <Aceptar>                 <Cancelar>               │ 
 │                                                                     │ 
 └─────────────────────────────────────────────────────────────────────┘ 
oracle@servidororacle:~$ sudo systemctl start postfix 
oracle@servidororacle:~$ mailq
oracle@servidororacle:~$ sudo apt-get install mailutils


--INSTALACION Y CONFIGURACION DEL PAQUETE UTL_MAIL
--Descargar paquetes

SQL> @$ORACLE_HOME/rdbms/admin/utlmail.sql
SQL> @$ORACLE_HOME/rdbms/admin/prvtmail.plb
SQL> alter session set SMTP_OUT_SERVER='babuino-smtp.gonzalonazareno.org';


--Otorgar permisos al usuario
SQL> grant execute on UTL_SMTP to paloma;
SQL> grant execute on utl_mail to paloma;
SQL> grant execute on sys.UTL_TCP to paloma;
SQL> grant execute on sys.UTL_SMTP to paloma;

--Crear, añadir y asignar ACL para el uso de la red
create or replace procedure prueba_correo
is
BEGIN
  DBMS_NETWORK_ACL_ADMIN.CREATE_ACL(acl         => 'www.xml',
                                    description => 'WWW ACL',
                                    principal   => 'PALOMA',
                                    is_grant    => true,
                                    privilege   => 'connect');
 
  DBMS_NETWORK_ACL_ADMIN.ADD_PRIVILEGE(acl       => 'www.xml',
                                       principal => 'PALOMA',
                                       is_grant  => true,
                                       privilege => 'resolve');
 
  DBMS_NETWORK_ACL_ADMIN.ASSIGN_ACL(acl  => 'www.xml',
                                    host => 'babuino-smtp.gonzalonazareno.org');
END;
/
COMMIT;
exec prueba_correo;


--Procedimiento para mandar correos:
create or replace procedure Enviar(p_envia varchar2, 
   																 p_recibe varchar2, 
   																 p_asunto varchar2, 
  																 p_cuerpo varchar2, 
   																 p_host varchar2) 
IS 
  v_mailhost varchar2(80) := ltrim(rtrim(p_host)); 
  v_mail_conn    utl_smtp.connection;  
   
  v_crlf varchar2( 2 ):= CHR( 13 ) || CHR( 10 ); 
  v_mesg varchar2( 1000 ); 
BEGIN 
  v_mail_conn := utl_smtp.open_connection(mailhost, 25); 
  v_mesg:= 'Date: ' || TO_CHAR( SYSDATE, 'dd Mon yy hh24:mi:ss' ) || v_crlf || 
         'From:  <'||p_envia||'>' || v_crlf || 
         'Subject: '||p_asunto || v_crlf || 
         'To: '||p_recibe || v_crlf || 
         '' || v_crlf || p_cuerpo; 
 
  utl_smtp.helo(v_mail_conn, v_mailhost); 
  utl_smtp.mail(v_mail_conn, p_envia);  
  utl_smtp.rcpt(v_mail_conn, p_recibe); 
  utl_smtp.data(v_mail_conn, v_mesg);   
  utl_smtp.quit(v_mail_conn);         
END; 
/


--TRIGGER QUE ENVIE CORREOS
alter table INVESTIGADORES add email varchar2(30);
update INVESTIGADORES set email='palomagarciacampon08@gmail.com' where nif='49129431M';


create or replace trigger CorreoInvestigadorPuntuacion
after insert or update of valor on puntuaciones
for each row
declare
begin
	if :new.valor<5 then
		EnviarCorreoInvestigador(:new.nif_cat, :new.COD_ASP, :new.COD_VERS, :new.COD_EXP);
	end if;
end CorreoInvestigadorPuntuacion;
/


create or replace procedure EnviarCorreoInvestigador (p_nifCat catadores.nif%type, 
																											p_codAsp aspectos.codigo%type, 
																											p_codVer versiones.codigo%type, 
																											p_codExp experimentos.codigo%type)
is
	v_correo investigadores.email%type;
begin
	v_correo:=ObtenerCorreoInvestigador(p_codExp);
	if v_correo!='-1' then
		CrearCorreo(p_nifCat, p_codAsp, p_codVer, p_codExp, v_correo);
	end if;
end EnviarCorreoInvestigador;
/


create or replace function ObtenerCorreoInvestigador(p_CodExp experimentos.codigo%type)
return experimentos.codigo%type
is
	v_correo investigadores.email%type;
begin
	select email into v_correo
	from investigadores
	where nif=(select nif_inv
						 from experimentos
						 where codigo=p_codExp);
	return v_correo;
exception
	when NO_DATA_FOUND then
		return '-1';
end ObtenerCorreoInvestigador;
/


create or replace procedure CrearCorreo(p_nifCat catadores.nif%type, 																					
																				p_codAsp aspectos.codigo%type, 																					
																				p_codVer versiones.codigo%type, 																				
																				p_codExp experimentos.codigo%type, 																					
																				p_correo investigadores.email%type)
is
	v_fechaPrueba versiones.fecha_prueba%type;
	v_nombreAsp 	aspectos.descripcion%type;
	v_dirCat 			catadores.direccion%type;
begin
	v_fechaPrueba:=SaberFechaPrueba(p_codVer, p_codExp);
	v_nombreAsp:=SaberNombreAspecto(p_codAsp);
	v_dirCat:=SaberDireccionCatador(p_nifCat);
	EnviarCorreo(p_correo, v_fechaPrueba, v_nombreAsp, v_dirCat, p_codExp, p_codVer);
end CrearCorreo;
/

create or replace function SaberDireccionCatador(p_nifCat catadores.nif%type)
return catadores.direccion%type
is
	v_direccion catadores.direccion%type;
begin
	select direccion into v_direccion
	from catadores
	where nif=p_nifCat;
	return v_direccion;
exception
	when NO_DATA_FOUND then
		return '-1';
end SaberDireccionCatador;
/


create or replace function SaberNombreAspecto(p_codAsp aspectos.codigo%type)
return aspectos.descripcion%type
is
	v_descripcion aspectos.descripcion%type;
begin
	select descripcion into v_descripcion
	from aspectos
	where codigo=p_codAsp;
	return v_descripcion;
exception
	when NO_DATA_FOUND then
		return '-1';
end SaberNombreAspecto;
/


create or replace function SaberFechaPrueba(p_codVer versiones.codigo%type,
																						p_codAsp aspectos.codigo%type)
return versiones.fecha_prueba%type
is
	v_fecha versiones.fecha_prueba%type;
begin
	select fecha_prueba into v_fecha
	from versiones
	where codigo=p_codVer
	and cod_exp=p_codAsp;
	return v_fecha;
exception
	when NO_DATA_FOUND then
		return '01/01/0001';
end SaberFechaPrueba;
/


create or replace procedure EnviarCorreo (p_correo 			investigadores.email%type, 
																					p_fechaPrueba versiones.fecha_prueba%type, 
																					p_nombreAsp 	aspectos.descripcion%type, 
																					p_dirCat 			catadores.direccion%type,
																					p_codExp 			experimentos.codigo%type,
																					p_codVer 			versiones.codigo%type)
is
	v_cuerpo varchar2(1000);
begin
	v_cuerpo:='Se le informa que la versión '||p_codVer||' del experimento '||p_codExp||' a sido puntuado con una nota muy baja:'||chr(10);
	if to_char(p_fechaPrueba,'dd/mm/yyyy')!='01/01/0001'then
		v_cuerpo:=v_cuerpo||'Fecha de la prueba: '||p_fechaprueba||chr(10);
	end if;
	if p_nombreAsp!='-1' then
		v_cuerpo:=v_cuerpo||'Aspecto: '||p_nombreAsp||chr(10);
	end if;
	if p_dirCat!='-1' then
		v_cuerpo:=v_cuerpo||'Dirección del catador: '||p_dirCat||chr(10);
	end if;
	Enviar ('oracle@servidororacle',p_correo,'Puntuacion baja en versiones',v_cuerpo,'babuino-smtp.gonzalonazareno.org');
end EnviarCorreo;
/










