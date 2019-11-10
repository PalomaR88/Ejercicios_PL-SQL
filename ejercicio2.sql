--5. Añade a la tabla Actividades una columna llamada BalanceHotel. La columna contendrá la cantidad que debe pagar el hotel a la empresa (en cuyo caso tendrá signo positivo) o la empresa al hotel (en cuyo caso tendrá signo negativo) a causa de las Actividades Realizadas por los clientes. Realiza un procedimiento que rellene dicha columna y un trigger que la mantenga actualizada cada vez que la tabla ActividadesRealizadas sufra cualquier cambio.

alter table ACTIVIDADES add BalanceHotel number(6,2) default 0;


create or replace procedure IntroducirDatosBalance
is
    cursor c_balance is
    select a.codigo as codAct, a.comisionhotel as comision, a.costepersonahotel as costPersH, ar.numpersonas as numPer, e.codigoRegimen as codReg
    from actividades a, actividadesrealizadas ar, estancias e
    where a.codigo=ar.codigoactividad
    and ar.codigoestancia=e.codigo;
    v_balance c_balance%ROWTYPE;
begin
    for v_balance in c_balance loop
        InsertarDatoBalance(v_balance.codAct, v_balance.comision, v_balance.costPersH, v_balance.numPer, v_balance.codReg);
    end loop;
end IntroducirDatosBalance;
/


create or replace procedure InsertarDatoBalance(p_codAct 		actividades.codigo%type, 
                                                p_comision 	actividades.comisionhotel%type, 
                                                p_costPersH actividades.costepersonahotel%type, 
                                                p_numPer 		actividadesrealizadas.numpersonas%type, 
                                                p_codReg 		estancias.codigoRegimen%type)
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


create or replace procedure CambiarDatoBalance (p_codAct 	actividades.codigo%type,
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
			CambiarBalance(:new.codigoactividad, :new.codigoestancia, :new.fecha, :new.numPersonas, 1);
		when updating then
			CambiarBalance(:old.codigoactividad, :old.codigoestancia, :old.fecha, :old.numPersonas, 0);
			CambiarBalance(:new.codigoactividad, :new.codigoestancia, :new.fecha, :new.numPersonas, 1);
		when deleting then
			CambiarBalance(:old.codigoactividad, :old.codigoestancia, :old.fecha, :old.numPersonas, 0);
	end case;
end ActualizarBalanceActR;
/


create or replace procedure CambiarBalance (p_codAct actividades.codigo%type, p_codEst estancias.codigo%type, 
p_fecha actividadesrealizadas.fecha%type,
p_numPers actividadesrealizadas.numPersonas%type,
p_borraroponer number)
is
	v_comision 	actividades.comisionhotel%type;
	v_costPersH actividades.costepersonahotel%type;
	v_numPer 		actividadesrealizadas.numpersonas%type;
	v_codReg 		estancias.codigoRegimen%type;
begin
	select a.comisionhotel, a.costepersonahotel, e.codigoRegimen into v_comision, v_costPersH, v_codReg
    from actividades a, estancias e
    where a.codigo=p_codAct
    and e.codigo=p_codEst;
		if p_borraroponer=1 then
			InsertarDatoBalance (p_codAct, v_comision, v_costPersH, p_numPers, v_codReg);
		else
			EliminarDatoBalance(p_codAct, v_comision, v_costPersH, p_numPers, v_codReg);
		end if;
end;
/


create or replace procedure EliminarDatoBalance(p_codAct 		actividades.codigo%type, 
                                                p_comision 	actividades.comisionhotel%type, 
                                                p_costPersH actividades.costepersonahotel%type, 
                                                p_numPer 		actividadesrealizadas.numpersonas%type, 
                                                p_codReg 		estancias.codigoRegimen%type)
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




-- 6. Realiza los módulos de programación necesarios para que una actividad no sea realizada en una fecha concreta por más de 10 personas.


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
	update Participantes set numPer=numPer+p_numPer where codigoactividad=p_codAct and numPersonas=p_numPer;
end;
$$ LANGUAGE PLPGSQL;




sum(numpersonas) as numPer, codigoactividad, fecha

CREATE OR REPLACE TRIGGER name
(AFTER/BEFORE) (INSERT,UPDATE OR DELETE) ON nombretabla
FOR EACH (fila o sentencia)
BEGIN

END;
/
			
			
			


