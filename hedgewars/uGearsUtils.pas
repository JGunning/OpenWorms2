(*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2004-2012 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *)

{$INCLUDE "options.inc"}

unit uGearsUtils;
interface
uses uTypes;

procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword; const Tint: LongWord = $FFFFFFFF); 
function  ModifyDamage(dmg: Longword; Gear: PGear): Longword;
procedure ApplyDamage(Gear: PGear; AttackerHog: PHedgehog; Damage: Longword; Source: TDamageSource);
procedure spawnHealthTagForHH(HHGear: PGear; dmg: Longword);
procedure HHHurt(Hedgehog: PHedgehog; Source: TDamageSource);
procedure CheckHHDamage(Gear: PGear);
procedure CalcRotationDirAngle(Gear: PGear);
procedure ResurrectHedgehog(gear: PGear);
procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt; skipProximity: boolean = false);
function  CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear;
function  CheckGearsNear(mX, mY: LongInt; Kind: TGearsType; rX, rY: LongInt): PGear;
function  CheckGearDrowning(Gear: PGear): boolean;

var doStepHandlers: array[TGearType] of TGearStepProcedure;


implementation
uses uFloat, uSound, uCollisions, uUtils, uConsts, uVisualGears, uAIMisc,
    uVariables, uLandGraphics, uScript, uStats, uCaptions, uTeams, uStore,
    uLocale, uTextures, uRenderUtils, uRandom, SDLh, uDebug, uGears,
    uGearsList;

procedure doMakeExplosion(X, Y, Radius: LongInt; AttackingHog: PHedgehog; Mask: Longword; const Tint: LongWord);
var Gear: PGear;
    dmg, dmgBase: LongInt;
    fX, fY, tdX, tdY: hwFloat;
    vg: PVisualGear;
    i, cnt: LongInt;
begin
if Radius > 4 then AddFileLog('Explosion: at (' + inttostr(x) + ',' + inttostr(y) + ')');
if Radius > 25 then KickFlakes(Radius, X, Y);

if ((Mask and EXPLNoGfx) = 0) then
    begin
    vg:= nil;
    if Radius > 50 then vg:= AddVisualGear(X, Y, vgtBigExplosion)
    else if Radius > 10 then vg:= AddVisualGear(X, Y, vgtExplosion);
    if vg <> nil then
        vg^.Tint:= Tint;
    end;
if (Mask and EXPLAutoSound) <> 0 then PlaySound(sndExplosion);

(*if (Mask and EXPLAllDamageInRadius) = 0 then
    dmgRadius:= Radius shl 1
else
    dmgRadius:= Radius;
dmgBase:= dmgRadius + cHHRadius div 2;*)
dmgBase:= Radius shl 1 + cHHRadius div 2;
fX:= int2hwFloat(X);
fY:= int2hwFloat(Y);
Gear:= GearsList;
while Gear <> nil do
    begin
    dmg:= 0;
    //dmg:= dmgRadius  + cHHRadius div 2 - hwRound(Distance(Gear^.X - int2hwFloat(X), Gear^.Y - int2hwFloat(Y)));
    //if (dmg > 1) and
    if (Gear^.State and gstNoDamage) = 0 then
        begin
        case Gear^.Kind of
            gtHedgehog,
                gtMine,
                gtBall,
                gtMelonPiece,
                gtGrenade,
                gtClusterBomb,
            //    gtCluster, too game breaking I think
                gtSMine,
                gtCase,
                gtTarget,
                gtFlame,
                gtExplosives,
                gtStructure: begin
// Run the calcs only once we know we have a type that will need damage
                        tdX:= Gear^.X-fX;
                        tdY:= Gear^.Y-fY;
                        if hwRound(hwAbs(tdX)+hwAbs(tdY)) < dmgBase then
                            dmg:= dmgBase - max(hwRound(Distance(tdX, tdY)),Gear^.Radius);
                        if dmg > 1 then
                            begin
                            dmg:= ModifyDamage(min(dmg div 2, Radius), Gear);
                            //AddFileLog('Damage: ' + inttostr(dmg));
                            if (Mask and EXPLNoDamage) = 0 then
                                begin
                                if not Gear^.Invulnerable then
                                    ApplyDamage(Gear, AttackingHog, dmg, dsExplosion)
                                else
                                    Gear^.State:= Gear^.State or gstWinner;
                                end;
                            if ((Mask and EXPLDoNotTouchAny) = 0) and (((Mask and EXPLDoNotTouchHH) = 0) or (Gear^.Kind <> gtHedgehog)) then
                                begin
                                DeleteCI(Gear);
                                Gear^.dX:= Gear^.dX + SignAs(_0_005 * dmg + cHHKick, tdX)/(Gear^.Density/_3);
                                Gear^.dY:= Gear^.dY + SignAs(_0_005 * dmg + cHHKick, tdY)/(Gear^.Density/_3);

                                Gear^.State:= (Gear^.State or gstMoving) and (not gstLoser);
                                if not Gear^.Invulnerable then
                                    Gear^.State:= (Gear^.State or gstMoving) and (not gstWinner);
                                Gear^.Active:= true;
                                if Gear^.Kind <> gtFlame then FollowGear:= Gear
                                end;
                            if ((Mask and EXPLPoisoned) <> 0) and (Gear^.Kind = gtHedgehog) and (not Gear^.Invulnerable) then
                                Gear^.Hedgehog^.Effects[hePoisoned] := true;
                            end;

                        end;
                gtGrave: begin
// Run the calcs only once we know we have a type that will need damage
                        tdX:= Gear^.X-fX;
                        tdY:= Gear^.Y-fY;
                        if hwRound(hwAbs(tdX)+hwAbs(tdY)) < dmgBase then
                            dmg:= dmgBase - hwRound(Distance(tdX, tdY));
                        if dmg > 1 then
                            begin
                            dmg:= ModifyDamage(min(dmg div 2, Radius), Gear);
                            Gear^.dY:= - _0_004 * dmg;
                            Gear^.Active:= true
                            end
                        end;
            end;
        end;
    Gear:= Gear^.NextGear
    end;

if (Mask and EXPLDontDraw) = 0 then
    if (GameFlags and gfSolidLand) = 0 then
        begin
        cnt:= DrawExplosion(X, Y, Radius) div 1608; // approx 2 16x16 circles to erase per chunk
        if (cnt > 0) and (SpritesData[sprChunk].Texture <> nil) then
            for i:= 0 to cnt do
                AddVisualGear(X, Y, vgtChunk)
        end;

uAIMisc.AwareOfExplosion(0, 0, 0)
end;

function ModifyDamage(dmg: Longword; Gear: PGear): Longword;
var i: hwFloat;
begin
(* Invulnerability cannot be placed in here due to still needing kicks
   Not without a new damage machine.
   King check should be in here instead of ApplyDamage since Tiy wants them kicked less
*)
i:= _1;
if (CurrentHedgehog <> nil) and CurrentHedgehog^.King then
    i:= _1_5;
if (Gear^.Hedgehog <> nil) and (Gear^.Hedgehog^.King) then
    ModifyDamage:= hwRound(_0_01 * cDamageModifier * dmg * i * cDamagePercent * _0_5)
else
    ModifyDamage:= hwRound(_0_01 * cDamageModifier * dmg * i * cDamagePercent)
end;

procedure ApplyDamage(Gear: PGear; AttackerHog: PHedgehog; Damage: Longword; Source: TDamageSource);
var s: shortstring;
    vampDmg, tmpDmg, i: Longword;
    vg: PVisualGear;
begin
    if Damage = 0 then
        exit; // nothing to apply

    if (Gear^.Kind = gtHedgehog) then
        begin
        Gear^.LastDamage := AttackerHog;

        Gear^.Hedgehog^.Team^.Clan^.Flawless:= false;
        HHHurt(Gear^.Hedgehog, Source);
        AddDamageTag(hwRound(Gear^.X), hwRound(Gear^.Y), Damage, Gear^.Hedgehog^.Team^.Clan^.Color);
        tmpDmg:= min(Damage, max(0,Gear^.Health-Gear^.Damage));
        if (Gear <> CurrentHedgehog^.Gear) and (CurrentHedgehog^.Gear <> nil) and (tmpDmg >= 1) then
            begin
            if cVampiric then
                begin
                vampDmg:= hwRound(int2hwFloat(tmpDmg)*_0_8);
                if vampDmg >= 1 then
                    begin
                    // was considering pulsing on attack, Tiy thinks it should be permanent while in play
                    //CurrentHedgehog^.Gear^.State:= CurrentHedgehog^.Gear^.State or gstVampiric;
                    inc(CurrentHedgehog^.Gear^.Health,vampDmg);
                    str(vampDmg, s);
                    s:= '+' + s;
                    AddCaption(s, CurrentHedgehog^.Team^.Clan^.Color, capgrpAmmoinfo);
                    RenderHealth(CurrentHedgehog^);
                    RecountTeamHealth(CurrentHedgehog^.Team);
                    i:= 0;
                    while i < vampDmg do
                        begin
                        vg:= AddVisualGear(hwRound(CurrentHedgehog^.Gear^.X), hwRound(CurrentHedgehog^.Gear^.Y), vgtStraightShot);
                        if vg <> nil then
                            with vg^ do
                                begin
                                Tint:= $FF0000FF;
                                State:= ord(sprHealth)
                                end;
                        inc(i, 5);
                        end;
                    end
                end;
        if ((GameFlags and gfKarma) <> 0) and 
        ((GameFlags and gfInvulnerable) = 0)
        and (not CurrentHedgehog^.Gear^.Invulnerable) then
            begin // this cannot just use Damage or it interrupts shotgun and gets you called stupid
            inc(CurrentHedgehog^.Gear^.Karma, tmpDmg);
            CurrentHedgehog^.Gear^.LastDamage := CurrentHedgehog;
            spawnHealthTagForHH(CurrentHedgehog^.Gear, tmpDmg);
            end;
        uStats.HedgehogDamaged(Gear, AttackerHog, Damage, false);    
        end;
    end
    else if Gear^.Kind <> gtStructure then // not gtHedgehog nor gtStructure
        begin
        Gear^.Hedgehog:= AttackerHog;
        end;
    inc(Gear^.Damage, Damage);
    
    ScriptCall('onGearDamage', Gear^.UID, Damage);
end;

procedure spawnHealthTagForHH(HHGear: PGear; dmg: Longword);
var tag: PVisualGear;
begin
tag:= AddVisualGear(hwRound(HHGear^.X), hwRound(HHGear^.Y), vgtHealthTag, dmg);
if (tag <> nil) then
    tag^.Hedgehog:= HHGear^.Hedgehog; // the tag needs the tag to determine the text color
AllInactive:= false;
HHGear^.Active:= true;
end;
    
procedure HHHurt(Hedgehog: PHedgehog; Source: TDamageSource);
begin
if (Source = dsFall) or (Source = dsExplosion) then
    case random(3) of
        0: PlaySound(sndOoff1, Hedgehog^.Team^.voicepack);
        1: PlaySound(sndOoff2, Hedgehog^.Team^.voicepack);
        2: PlaySound(sndOoff3, Hedgehog^.Team^.voicepack);
    end
else if (Source = dsPoison) then
    case random(2) of
        0: PlaySound(sndPoisonCough, Hedgehog^.Team^.voicepack);
        1: PlaySound(sndPoisonMoan, Hedgehog^.Team^.voicepack);
    end
else
    case random(4) of
        0: PlaySound(sndOw1, Hedgehog^.Team^.voicepack);
        1: PlaySound(sndOw2, Hedgehog^.Team^.voicepack);
        2: PlaySound(sndOw3, Hedgehog^.Team^.voicepack);
        3: PlaySound(sndOw4, Hedgehog^.Team^.voicepack);
    end
end;

procedure CheckHHDamage(Gear: PGear);
var 
    dmg: Longword;
    i: LongInt;
    particle: PVisualGear;
begin
    if _0_4 < Gear^.dY then
        begin
        dmg := ModifyDamage(1 + hwRound((hwAbs(Gear^.dY) - _0_4) * 70), Gear);
        PlaySound(sndBump);
        if dmg < 1 then
            exit;

        for i:= min(12, (3 + dmg div 10)) downto 0 do
            begin
            particle := AddVisualGear(hwRound(Gear^.X) - 5 + Random(10), hwRound(Gear^.Y) + 12, vgtDust);
            if particle <> nil then
                particle^.dX := particle^.dX + (Gear^.dX.QWordValue / 21474836480);
            end;

        if (Gear^.Invulnerable) then
            exit;

        //if _0_6 < Gear^.dY then
        //    PlaySound(sndOw4, Gear^.Hedgehog^.Team^.voicepack)
        //else
        //    PlaySound(sndOw1, Gear^.Hedgehog^.Team^.voicepack);

        if Gear^.LastDamage <> nil then
            ApplyDamage(Gear, Gear^.LastDamage, dmg, dsFall)
        else
            ApplyDamage(Gear, CurrentHedgehog, dmg, dsFall);
    end
end;


procedure CalcRotationDirAngle(Gear: PGear);
var 
    dAngle: real;
begin
    dAngle := (Gear^.dX.QWordValue + Gear^.dY.QWordValue) / $80000000;
    if not Gear^.dX.isNegative then
        Gear^.DirAngle := Gear^.DirAngle + dAngle
    else
        Gear^.DirAngle := Gear^.DirAngle - dAngle;

    if Gear^.DirAngle < 0 then
        Gear^.DirAngle := Gear^.DirAngle + 360
    else if 360 < Gear^.DirAngle then
        Gear^.DirAngle := Gear^.DirAngle - 360
end;

function CheckGearDrowning(Gear: PGear): boolean;
var 
    skipSpeed, skipAngle, skipDecay: hwFloat;
    i, maxDrops, X, Y: LongInt;
    vdX, vdY: real;
    particle: PVisualGear;
    isSubmersible: boolean;
begin
    // probably needs tweaking. might need to be in a case statement based upon gear type
    Y:= hwRound(Gear^.Y);
    if cWaterLine < Y + Gear^.Radius then
        begin
        isSubmersible:= (Gear = CurrentHedgehog^.Gear) and (CurAmmoGear <> nil) and (CurAmmoGear^.AmmoType = amJetpack);
        skipSpeed := _0_25;
        skipAngle := _1_9;
        skipDecay := _0_87;
        X:= hwRound(Gear^.X);
        vdX:= hwFloat2Float(Gear^.dX);
        vdY:= hwFloat2Float(Gear^.dY);
        // this could perhaps be a tiny bit higher.
        if  (hwSqr(Gear^.dX) + hwSqr(Gear^.dY) > skipSpeed)
        and (hwAbs(Gear^.dX) > skipAngle * hwAbs(Gear^.dY)) then
            begin
            Gear^.dY.isNegative := true;
            Gear^.dY := Gear^.dY * skipDecay;
            Gear^.dX := Gear^.dX * skipDecay;
            CheckGearDrowning := false;
            PlaySound(sndSkip)
            end
        else
            begin
            if not isSubmersible then
                begin
                CheckGearDrowning := true;
                Gear^.State := gstDrowning;
                Gear^.RenderTimer := false;
                if (Gear^.Kind <> gtSniperRifleShot) and (Gear^.Kind <> gtShotgunShot)
                and (Gear^.Kind <> gtDEagleShot) and (Gear^.Kind <> gtSineGunShot) then
                    if Gear^.Kind = gtHedgehog then
                        begin
                        if Gear^.Hedgehog^.Effects[heResurrectable] then
                            ResurrectHedgehog(Gear)
                        else
                            begin
                            Gear^.doStep := @doStepDrowningGear;
                            Gear^.State := Gear^.State and (not gstHHDriven);
                            AddCaption(Format(GetEventString(eidDrowned), Gear^.Hedgehog^.Name), cWhiteColor, capgrpMessage);
                            end
                        end
                    else
                        Gear^.doStep := @doStepDrowningGear;
                        if Gear^.Kind = gtFlake then
                            exit // skip splashes 
                end;
            if ((not isSubmersible) and (Y < cWaterLine + 64 + Gear^.Radius))
            or (isSubmersible and (Y < cWaterLine + 2 + Gear^.Radius) and ((CurAmmoGear^.Pos = 0)
            and (CurAmmoGear^.dY < _0_01))) then
                // don't play splash if they are already way past the surface
                PlaySound(sndSplash)
            end;

        if ((cReducedQuality and rqPlainSplash) = 0)
        and (((not isSubmersible) and (Y < cWaterLine + 64 + Gear^.Radius))
        or (isSubmersible and (Y < cWaterLine + 2 + Gear^.Radius) and ((CurAmmoGear^.Pos = 0)
        and (CurAmmoGear^.dY < _0_01)))) then
            begin
            AddVisualGear(X, cWaterLine, vgtSplash);

            maxDrops := (Gear^.Radius div 2) + round(vdX * Gear^.Radius * 2) + round(vdY * Gear^.Radius * 2);
            for i:= max(maxDrops div 3, min(32, Random(maxDrops))) downto 0 do
                begin
                particle := AddVisualGear(X - 3 + Random(6), cWaterLine, vgtDroplet);
                if particle <> nil then
                    begin
                    particle^.dX := particle^.dX - vdX / 10;
                    particle^.dY := particle^.dY - vdY / 5;
                    end
                end
            end;
        if isSubmersible and (CurAmmoGear^.Pos = 0) then
            CurAmmoGear^.Pos := 1000
        end
    else
        CheckGearDrowning := false;
end;


procedure ResurrectHedgehog(gear: PGear);
var tempTeam : PTeam;
begin
    AttackBar:= 0;
    gear^.dX := _0;
    gear^.dY := _0;
    gear^.Damage := 0;
    gear^.Health := gear^.Hedgehog^.InitialHealth;
    gear^.Hedgehog^.Effects[hePoisoned] := false;
    if not CurrentHedgehog^.Effects[heResurrectable] then
        with CurrentHedgehog^ do 
            begin
            inc(Team^.stats.AIKills);
            FreeTexture(Team^.AIKillsTex);
            Team^.AIKillsTex := RenderStringTex(inttostr(Team^.stats.AIKills), Team^.Clan^.Color, fnt16);
            end;
    tempTeam := gear^.Hedgehog^.Team;
    DeleteCI(gear);
    FindPlace(gear, false, 0, LAND_WIDTH, true); 
    if gear <> nil then
        begin
        RenderHealth(gear^.Hedgehog^);
        ScriptCall('onGearResurrect', gear^.uid);
        gear^.State := gstWait;
    end;
    RecountTeamHealth(tempTeam);
end;

function CountNonZeroz(x, y, r, c: LongInt): LongInt;
var i: LongInt;
    count: LongInt = 0;
begin
if (y and LAND_HEIGHT_MASK) = 0 then
    for i:= max(x - r, 0) to min(x + r, LAND_WIDTH - 4) do
        if Land[y, i] <> 0 then
            begin
            inc(count);
            if count = c then
                exit(count)
            end;
CountNonZeroz:= count;
end;

procedure FindPlace(var Gear: PGear; withFall: boolean; Left, Right: LongInt; skipProximity: boolean);
var x: LongInt;
    y, sy: LongInt;
    ar: array[0..511] of TPoint;
    ar2: array[0..1023] of TPoint;
    cnt, cnt2: Longword;
    delta: LongInt;
    reallySkip, tryAgain: boolean;
begin
reallySkip:= false; // try not skipping proximity at first
tryAgain:= true;
while tryAgain do
    begin
    delta:= 250;
    cnt2:= 0;
    repeat
        x:= Left + LongInt(GetRandom(Delta));
        repeat
            inc(x, Delta);
            cnt:= 0;
            y:= min(1024, topY) - 2 * Gear^.Radius;
            while y < cWaterLine do
                begin
                repeat
                    inc(y, 2);
                until (y >= cWaterLine) or (CountNonZeroz(x, y, Gear^.Radius - 1, 1) = 0);

                sy:= y;

                repeat
                    inc(y);
                until (y >= cWaterLine) or (CountNonZeroz(x, y, Gear^.Radius - 1, 1) <> 0);

                if (y - sy > Gear^.Radius * 2)
                    and (((Gear^.Kind = gtExplosives)
                    and (y < cWaterLine)
                    and (reallySkip or (CheckGearsNear(x, y - Gear^.Radius, [gtFlame, gtHedgehog, gtMine, gtCase, gtExplosives], 60, 60) = nil))
                    and (CountNonZeroz(x, y+1, Gear^.Radius - 1, Gear^.Radius+1) > Gear^.Radius))
                or
                    ((Gear^.Kind <> gtExplosives)
                    and (y < cWaterLine)
                    and (reallySkip or (CheckGearsNear(x, y - Gear^.Radius, [gtFlame, gtHedgehog, gtMine, gtCase, gtExplosives], 110, 110) = nil)))) then
                 
                          begin
                    ar[cnt].X:= x;
                    if withFall then
                        ar[cnt].Y:= sy + Gear^.Radius
                    else
                        ar[cnt].Y:= y - Gear^.Radius;
                    inc(cnt)
                    end;

                inc(y, 45)
                end;

            if cnt > 0 then
                with ar[GetRandom(cnt)] do
                    begin
                    ar2[cnt2].x:= x;
                    ar2[cnt2].y:= y;
                    inc(cnt2)
                    end
        until (x + Delta > Right);

        dec(Delta, 60)
    until (cnt2 > 0) or (Delta < 70);
    if (cnt2 = 0) and skipProximity and (not reallySkip) then
        tryAgain:= true
    else tryAgain:= false;
    reallySkip:= true;
    end;

if cnt2 > 0 then
    with ar2[GetRandom(cnt2)] do
        begin
        Gear^.X:= int2hwFloat(x);
        Gear^.Y:= int2hwFloat(y);
        AddFileLog('Assigned Gear coordinates (' + inttostr(x) + ',' + inttostr(y) + ')');
        end
    else
    begin
    OutError('Can''t find place for Gear', false);
    if Gear^.Kind = gtHedgehog then
        Gear^.Hedgehog^.Effects[heResurrectable] := false;
    DeleteGear(Gear);
    Gear:= nil
    end
end;

function CheckGearNear(Gear: PGear; Kind: TGearType; rX, rY: LongInt): PGear;
var t: PGear;
begin
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);

while t <> nil do
    begin
    if (t <> Gear) and (t^.Kind = Kind) then
        if not((hwSqr(Gear^.X - t^.X) / rX + hwSqr(Gear^.Y - t^.Y) / rY) > _1) then
        exit(t);
    t:= t^.NextGear
    end;

CheckGearNear:= nil
end;


function CheckGearsNear(mX, mY: LongInt; Kind: TGearsType; rX, rY: LongInt): PGear;
var t: PGear;
begin
t:= GearsList;
rX:= sqr(rX);
rY:= sqr(rY);
while t <> nil do
    begin
    if t^.Kind in Kind then
        if not (hwSqr(int2hwFloat(mX) - t^.X) / rX + hwSqr(int2hwFloat(mY) - t^.Y) / rY > _1) then
            exit(t);
    t:= t^.NextGear
    end;
CheckGearsNear:= nil
end;
end.
