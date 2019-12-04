-- 4. Añade un campo email a los clientes y rellénalo para algunos de 
-- ellos. Realiza un trigger que cuando se rellene el campo Fecha de la 
-- Factura envíe por correo electrónico un resumen de la factura al 
-- cliente, incluyendo los datos fundamentales de la estancia, el 
-- importe de cada apartado y el importe total.

-- INSTALACION DEL CLIENTE DE CORREO POSTFIX
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


-- INSTALACION Y CONFIGURACION DEL PAQUETE UTL_MAIL
-- Descargar paquetes

SQL> @$ORACLE_HOME/rdbms/admin/utlmail.sql
SQL> @$ORACLE_HOME/rdbms/admin/prvtmail.plb
SQL> alter session set SMTP_OUT_SERVER='babuino-smtp.gonzalonazareno.org';



-- Otorgar permisos al usuario
SQL> grant execute on UTL_SMTP to paloma;
SQL> grant execute on utl_mail to paloma;
SQL> grant execute on sys.UTL_TCP to paloma;
SQL> grant execute on sys.UTL_SMTP to paloma;



-- Crear, añadir y asignar ACL para el uso de la red
create or replace procedure prueba_correo
is
begin
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
end prueba_correo;
/

exec prueba_correo;


-- Procedimiento para mandar correos:
create or replace procedure Enviar(p_envia varchar2, 
				   p_recibe varchar2, 
   				   p_asunto varchar2, 
  				   p_cuerpo varchar2, 
   				   p_host varchar2) 
is
	v_mailhost varchar2(80) := ltrim(rtrim(p_host));
	v_mail_conn    utl_smtp.connection;
	v_crlf varchar2( 2 ):= CHR( 13 ) || CHR( 10 );
	v_mesg varchar2( 1000 ); 
begin
	v_mail_conn := utl_smtp.open_connection(mailhost, 25); 
	v_mesg:= 'Date: ' ||TO_CHAR( SYSDATE, 'dd Mon yy hh24:mi:ss' )|| v_crlf ||
			 'From:  <'||p_envia||'>' || v_crlf || 
			 'Subject: '||p_asunto || v_crlf ||
			 'To: '||p_recibe || v_crlf ||
			 '' || v_crlf || p_cuerpo;
	utl_smtp.helo(v_mail_conn, v_mailhost);
	utl_smtp.mail(v_mail_conn, p_envia);
	utl_smtp.rcpt(v_mail_conn, p_recibe);
	utl_smtp.data(v_mail_conn, v_mesg);
	utl_smtp.quit(v_mail_conn);         
end Enviar; 
/


-- TRIGGER QUE ENVIE CORREOS
create or replace trigger EnviarCorreoCliente
after insert or update of fecha on facturas
for each row
declare
	v_correo personas.email%type;
	select p.nif as v_nif, p.nombre as v_nombre, 
		   p.apellidos as v_apellidos, 
		   e.fechainicio as v_fechaInicio, 
		   e.fechafin as v_fechaFin, 
		   e.codigoregimen as v_codReg, 
		   h.codigotipo as v_tipoHab
	from personas p, estancias e, habitaciones h
	where e.codigo=:new.codigoestancia
	and e.numerohabitacion=h.numero
	and p.nif=e.nifcliente;
begin
	v_correo:=DevolverEmail(:new.codigoestancia);
	if v_correo!='-1' then
		RellenarPaqueteFactura(:new.codigoestancia, 
							   v_fechaInicio, v_fechaFin, 
							   v_codReg, v_tipoHab);
		MandarCorreo(v_NIF, v_NOMBRE, v_APELLIDOS, v_FECHAINICIO, 
					 v_FECHAFIN, v_correo);
	end if;
end CorreoInvestigadorPuntuacion;
/

create or replace procedure RellenarPaqueteFactura(p_codEst estancias.codigo%type,
    						   p_fechaInicio estancias.FECHAINICIO%type,
    						   p_fechaFin estancias.FECHAFIN%type,
    						   p_codReg estancias.CodigoRegimen%type,
    						   p_codTipoHab habitaciones.CodigoTipo%type)
is
begin
	RellenarDatosEstancia(p_codEst, p_fechaInicio, p_fechaFin, p_codReg, p_codTipoHab);
	RellenarGastosExtras(p_codEst);
	RellenarActividades(p_codEst);
end RellenarPaqueteFactura;
/

create or replace procedure RellenarGastosExtras (p_codEst estancias.codigo%type)
is
	cursor c_gastosextras
	is
	select concepto, cuantia
	from gastosextras
	where codigoestancia=p_codEst;
	v_gastoextra c_gastosExtras%ROWTYPE;
begin
	for v_gastoextra in c_gastosExtras loop
		CrearFilaPaqueteFactura(v_gastoextra.concepto, v_gastoextra.cuantia);
	end loop;
end RellenarGastosExtras;
/

create or replace procedure RellenarActividades(p_codEst estancias.codigo%type)
is
	cursor c_actividades
	is
	select a.precioporpersona as PORPERSONA, 
		   a.nombre as ACTIVIDAD, 
		   ar.numpersonas as NUMPERSONA
	from actividades a, actividadesrealizadas ar
	where ar.codigoestancia=p_codEst
	and ar.codigoactividad=a.codigo
	and ar.abonado=0;
	v_actividades c_actividades%ROWTYPE;
	v_coste number(6,2);
begin
	for v_actividades in c_actividades loop
		v_coste:=v_actividades.PORPERSONA*v_actividades.NUMPERSONA;
		CrearFilaPaqueteFactura(v_actividades.ACTIVIDAD, v_coste);
	end loop;
end RellenarActividades;
/


create or replace function DevolverEmail (p_codEst facturas.codigoestancia%type)
return personas.email%type
is
	v_email personas.email%type;
begin
	select EMAIL into v_email
	from PERSONAS
	where NIF = (select NIFCliente
	from ESTANCIAS
	where CODIGO = p_codEst);
	return v_email;
exception
	when NO_DATA_FOUND then
		return '-1';
end DevolverEmail;
/


create or replace procedure RellenarDatosEstancia(p_codEst estancias.codigo%type,
  						  p_fechaInicio estancias.FECHAINICIO%type,
      						  p_fechaFin estancias.FECHAFIN%type,
 	 					  p_codReg estancias.CodigoRegimen%type,
	  					  p_codTipoHab habitaciones.CodigoTipo%type)
is
	v_dias number;
	v_codTemp temporadas.codigo%type;
	v_precioPorDia tarifas.PrecioporDia%type;
begin
	v_dias:=ObtenerNumeroDias(p_fechaInicio, p_fechaFin);
	for i in 1..v_dias loop
		v_codTemp:=ObtenerTemporada(p_fechaFin+i);
		v_precioPorDia:=ObtenerPrecioPorDia(v_codTemp, p_codReg, p_codTipoHab);
		CrearFilaPaqueteFactura('Dia '||i, v_precioPorDia);
	end loop;
end RellenarDatosEstancia;
/


create or replace function ObtenerNumeroDias(p_fechaInicio estancias.FECHAINICIO%type,
					     p_fechaFin estancias.FECHAFIN%type)
return number
is
	v_dias number;
begin
	v_dias:=trunc(p_fechaFin-p_fechaInicio);
	return v_dias;
end ObtenerNumeroDias;
/


create or replace function ObtenerTemporada (p_fecha estancias.FECHAINICIO%type)
return temporadas.codigo%type
is
	cursor c_temporadas
	is
	select fecha_inicio, fecha_fin, codigo
	from temporadas;
	v_temporada c_temporadas%ROWTYPE;
begin
	for v_temporada in c_temporadas loop
		if p_fecha between v_temporada.fecha_inicio and v_temporada.fecha_fin then
			return v_temporada.codigo;
		end if;
	end loop;
end ObtenerTemporada;
/


create or replace function ObtenerPrecioPorDia (p_codTemp temporadas.codigo%type,
						p_codReg estancias.CodigoRegimen%type,
						p_codTipoHab habitaciones.CodigoTipo%type)
return number
is
	v_cuantia tarifas.preciopordia%type;
begin
	select preciopordia into v_cuantia
	from tarifas
	where codigotipohabitacion=p_codTipoHab
	and codigoRegimen=p_codReg
	and codigoTemporada=p_codTemp;
	return v_cuantia;
end ObtenerPrecioPorDia;
/


create or replace procedure CrearFilaPaqueteFactura(p_concepto varchar2,
    												p_cuantia number)
is
begin
	PkgFactura.v_TabFactura(PkgFactura.v_TabFactura.LAST+1).concepto:=p_concepto;
	PkgFactura.v_TabFactura(PkgFactura.v_TabFactura.LAST).cuantia:=p_cuantia;
exception
	when value_error then
		PkgFactura.v_TabFactura(1).concepto:=p_concepto;
		PkgFactura.v_TabFactura(1).cuantia:=p_cuantia;
end CrearFilaPaqueteFactura;
/


create or replace procedure MandarCorreo(p_NIF personas.nif%type,  						 															 
										 p_NOMBRE personas.nombre%type,
 										 p_APELLIDOS personas.apellidos%type,
 										 p_FECHAINICIO estancias.fechainicio%type,
 										 p_FECHAFIN estancias.fechafin%type,
 										 p_correo personas.email%type)
is
	v_cont number(6,2):=0;
	v_cuerpomedio varchar2(500);
	v_cuerpo varchar2(1000);
begin
	for i in PkgFactura.v_TabFactura.FIRST .. PkgFactura.v_TabFactura.LAST loop
		v_cuerpo:=(v_cuerpo||PkgFactura.v_TabFactura(i).concepto||'  -	'||
				   PkgFactura.v_TabFactura(i).cuantia||chr(10));
		v_cont:=v_cont+PkgFactura.v_TabFactura(i).cuantia;
	end loop;
	enviar ('oracle@servidororacle', p_correo, 'Hotel Rural', 'Estimado cliente '||
			p_nombre ||' '||p_apellidos||chr(10)||
			'Su factura para la estancia en Hotel Rural durante los dias '||
			p_fechainicio||' '||p_fechafin||' ya está disponible.'||chr(10)||
			v_cuerpo||'Total: '||v_cont||chr(10)||'Atentamente, la empresa'||chr(10)||
			sysdate, 'babuino-smtp.gonzalonazareno.org');
end MandarCorreo;
/



-- 5. Añade a la tabla Actividades una columna llamada BalanceHotel. 
-- La columna contendrá la cantidad que debe pagar el hotel a la empresa 
-- (en cuyo caso tendrá signo positivo) o la empresa al hotel (en cuyo 
-- caso tendrá signo negativo) a causa de las Actividades Realizadas por 
-- los clientes. Realiza un procedimiento que rellene dicha columna y un 
-- trigger que la mantenga actualizada cada vez que la tabla 
-- ActividadesRealizadas sufra cualquier cambio.

alter table ACTIVIDADES add BalanceHotel number(6,2) default 0;


create or replace procedure IntroducirDatosBalance
is
    cursor c_balance is
    select a.codigo as codAct, a.comisionhotel as comision, 
		   a.costepersonahotel as costPersH, ar.numpersonas as numPer, 
		   e.codigoRegimen as codReg
    from actividades a, actividadesrealizadas ar, estancias e
    where a.codigo=ar.codigoactividad
    and ar.codigoestancia=e.codigo;
    v_balance c_balance%ROWTYPE;
begin
    for v_balance in c_balance loop
        InsertarDatoBalance(v_balance.codAct, v_balance.comision, 
							v_balance.costPersH, v_balance.numPer, 
							v_balance.codReg);
    end loop;
end IntroducirDatosBalance;
/


create or replace procedure InsertarDatoBalance(p_codAct actividades.codigo%type, 
                                                p_comision 	actividades.comisionhotel%type, 
                                                p_costPersH actividades.costepersonahotel%type, 
                                                p_numPer actividadesrealizadas.numpersonas%type, 
                                                p_codReg estancias.codigoRegimen%type)
is
    v_balanceOld actividades.BalanceHotel%type;
    v_balanceNew actividades.BalanceHotel%type;
begin
    select BalanceHotel into v_balanceOld
    from actividades
    where codigo=p_codAct;
    if p_codReg='TI' then
        v_balanceNew:=v_balanceOld-p_numPer*p_costPersH;
        CambiarDatoBalance(p_codAct,v_balanceNew);
    else
        v_balanceNew:=v_balanceOld+p_numPer*p_comision;
    end if;
    CambiarDatoBalance(p_codAct,v_balanceNew);
end InsertarDatoBalance;
/


create or replace procedure CambiarDatoBalance (p_codAct actividades.codigo%type,
                                                p_balance actividades.BalanceHotel%type)
is
begin
    update ACTIVIDADES 
    set BalanceHotel=p_balance 
    where codigo=p_codAct;
end CambiarDatoBalance;
/



create or replace trigger ActualizarBalanceActR
after insert or update or delete on actividadesrealizadas
for each row
declare
begin
	case 
		when inserting then
			CambiarBalance(:new.codigoactividad, :new.codigoestancia, 
						   :new.fecha, :new.numPersonas, 1);
		when updating then
			CambiarBalance(:old.codigoactividad, :old.codigoestancia, 
						   :old.fecha, :old.numPersonas, 0);
			CambiarBalance(:new.codigoactividad, :new.codigoestancia, 
						   :new.fecha, :new.numPersonas, 1);
		when deleting then
			CambiarBalance(:old.codigoactividad, :old.codigoestancia, 
						   :old.fecha, :old.numPersonas, 0);
	end case;
end ActualizarBalanceActR;
/


create or replace procedure CambiarBalance (p_codAct actividades.codigo%type, 
											p_codEst estancias.codigo%type, 
											p_fecha actividadesrealizadas.fecha%type,
											p_numPers actividadesrealizadas.numPersonas%type,
											p_borraroponer number)
is
	v_comision actividades.comisionhotel%type;
	v_costPersH actividades.costepersonahotel%type;
	v_numPer actividadesrealizadas.numpersonas%type;
	v_codReg estancias.codigoRegimen%type;
begin
	select a.comisionhotel, a.costepersonahotel, e.codigoRegimen 
		   into v_comision, v_costPersH, v_codReg
    from actividades a, estancias e
    where a.codigo=p_codAct
    and e.codigo=p_codEst;
		if p_borraroponer=1 then
			InsertarDatoBalance (p_codAct, v_comision, v_costPersH, 
								 p_numPers, v_codReg);
		else
			EliminarDatoBalance(p_codAct, v_comision, v_costPersH, 
								p_numPers, v_codReg);
		end if;
end CambiarBalance;
/


create or replace procedure EliminarDatoBalance(p_codAct actividades.codigo%type, 
                                                p_comision actividades.comisionhotel%type, 
                                                p_costPersH actividades.costepersonahotel%type, 
                                                p_numPer actividadesrealizadas.numpersonas%type, 
                                                p_codReg estancias.codigoRegimen%type)
is
    v_balanceOld actividades.BalanceHotel%type;
    v_balanceNew actividades.BalanceHotel%type;
begin
    select BalanceHotel into v_balanceOld
    from actividades
    where codigo=p_codAct;
    if p_codReg='TI' then
        v_balanceNew:=v_balanceOld+p_numPer*p_costPersH;
        CambiarDatoBalance(p_codAct,v_balanceNew);
    else
        v_balanceNew:=v_balanceOld-p_numPer*p_comision;
    end if;
    CambiarDatoBalance(p_codAct,v_balanceNew);
end EliminarDatoBalance;
/




-- 6. Realiza los módulos de programación necesarios para que una 
-- actividad no sea realizada en una fecha concreta por más de 10 personas.

create trigger CrearTablaParticipantes
before insert or update or delete on actividadesrealizadas
execute procedure RellenarTabla();

create or replace function RellenarTabla()
returns trigger as $$
declare
begin
	create temp table Participantes as
	select sum(numpersonas) as numPer, codigoactividad, fecha
	from actividadesrealizadas
	group by codigoactividad, fecha;
	return new;
end;
$$ LANGUAGE PLPGSQL;


create trigger Max10Participantes
before insert or update on actividadesrealizadas
for each row
	execute procedure NoPermitirMasDe10();
	


create or replace function NoPermitirMasDe10()
returns trigger as $$
begin
	PERFORM SumarParticipantes(new.codigoactividad, new.fecha, new.numPersonas);
return new;
end;
$$ LANGUAGE PLPGSQL;


create or replace function SumarParticipantes(p_codAct actividades.codigo%type, 
											  p_fecha actividadesrealizadas.fecha%type, 
											  p_numPer actividadesrealizadas.numPersonas%type)
returns numeric as $$
declare
	v_numero numeric;
begin
	select numPer into v_numero
	from Participantes
	where codigoactividad=p_codAct
	and fecha=p_fecha;
	v_numero:=v_numero+p_numPer;
	if v_numero+p_numPer>10 then
		RAISE EXCEPTION 'Esta actividad ya está llena a esta hora';
	else
			if not_data_found then
				PERFORM AñadirFilaParticipantes(p_codAct, p_fecha, p_numPer);
			else
				PERFORM SumarParticipantes (p_codAct, p_fecha, v_numero);
			end if;
	end if;
	drop table Participantes;
end;
$$ LANGUAGE PLPGSQL;


create or replace function AñadirFilaParticipantes(p_codAct actividades.codigo%type, 
												   p_fecha actividadesrealizadas.fecha%type, 
												   p_numPer actividadesrealizadas.numPersonas%type)
returns numeric as $$
declare
begin
	insert into Participantes values (p_numPer, p_codAct, p_numPer);
end;
$$ LANGUAGE PLPGSQL;


create or replace function SumarParticipantes (p_codAct actividades.codigo%type, 
											   p_fecha actividadesrealizadas.fecha%type, 
											   p_numPer actividadesrealizadas.numPersonas%type)
returns numeric as $$
declare
begin
	update Participantes 
		set numPer=numPer+p_numPer 
		where codigoactividad=p_codAct 
		and numPersonas=p_numPer;
end;
$$ LANGUAGE PLPGSQL;




sum(numpersonas) as numPer, codigoactividad, fecha

CREATE OR REPLACE TRIGGER name
(AFTER/BEFORE) (INSERT,UPDATE OR DELETE) ON nombretabla
FOR EACH (fila o sentencia)
BEGIN

END;
/
			
			
			


