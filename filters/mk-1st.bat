@echo off
rem $Header: /users/source/archives/vile.vcs/filters/RCS/mk-1st.bat,v 1.3 2000/07/27 02:13:36 tom Exp $
rem like mk-1st.awk, used to generate lists from genmake.mak

echo # generated by %0.bat

rem chew it up into small bites so the "enhanced" shell will see the lines.
sort <%1 >genmake.tmp
goto %2

:extern
echo ALL_C	= \
FOR /F "eol=# tokens=1,2,3 delims=	" %%i in (genmake.tmp) do if %%k==c echo 	vile-%%i-filt$x \
echo.
if "%LEX%" == "" goto done
echo ALL_LEX	= \
FOR /F "eol=# tokens=1,2,3 delims=	" %%i in (genmake.tmp) do if %%k==l echo 	vile-%%i-filt$x \
echo.
goto done

:intern
echo OBJ_C	= \
FOR /F "eol=# tokens=1,2,3 delims=	" %%i in (genmake.tmp) do if %%k==c echo 	%%j$o \
echo.
echo OBJ_LEX	= \
FOR /F "eol=# tokens=1,2,3 delims=	" %%i in (genmake.tmp) do if %%k==l echo 	%%j$o \
echo.
goto done

:done
del genmake.tmp

echo KEYS	= \
FOR %%i in (*.key) do echo 	%%i \
