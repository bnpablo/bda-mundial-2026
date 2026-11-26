"""
Universidad Nacional de La Matanza
Materia      : Bases de Datos Aplicada (3641)
Comision     : 02-5600 | Grupo N° 4
Integrantes  : Avila, Agustin | Blanco, Pablo | Leopaldi, Agustin | Sosa, Jesus
Fecha        : 2026-11-25
Archivo      : app_mundial.py
Objetivo     : Entrega 9. Aplicacion de escritorio sencilla para MundialDB, con tres pantallas:
                 - Paises: alta, modificacion y baja de Torneo.Pais.
                 - Importacion: elige un archivo CSV y ejecuta la importacion de arbitros
                   de la Entrega 6.
                 - Reportes: ejecuta un reporte XML de la Entrega 7 y lo guarda en un archivo.
               Toda escritura y toda importacion pasan por los procedimientos almacenados de
               la base (Torneo.usp_Pais_*, Importacion.usp_ImportarArbitrosCsv): la aplicacion
               no ejecuta INSERT, UPDATE ni DELETE. Las validaciones las hacen los SP y la
               aplicacion muestra su mensaje.
Requisitos   : Python 3.9 o posterior, el modulo pyodbc y ODBC Driver 18 para SQL Server.
               Se conecta con la cuenta de Windows de quien la ejecuta.
Ejecucion    : python app_mundial.py
               La instancia y la base se pueden cambiar con las variables de entorno
               MUNDIAL_SERVIDOR y MUNDIAL_BASE.
"""
import os
import re
import tkinter as tk
from contextlib import closing
from tkinter import filedialog, messagebox, ttk

import pyodbc

SERVIDOR = os.environ.get("MUNDIAL_SERVIDOR", r"localhost\SQLEXPRESS")
BASE = os.environ.get("MUNDIAL_BASE", "MundialDB")
CADENA = (
    "DRIVER={ODBC Driver 18 for SQL Server};SERVER=%s;DATABASE=%s;"
    "Trusted_Connection=yes;TrustServerCertificate=yes;" % (SERVIDOR, BASE)
)

CONFEDERACIONES = ("UEFA", "CONMEBOL", "CONCACAF", "CAF", "AFC", "OFC")
ARCHIVO_ARBITROS = r"C:\Importar\referees.csv"

REPORTES_XML = {
    "Selecciones y plantillas": ("Reportes.usp_ReportarPlantillas", "plantillas.xml"),
    "Designaciones arbitrales": ("Reportes.usp_ReportarDesignaciones", "designaciones.xml"),
}


def conectar():
    return pyodbc.connect(CADENA, autocommit=True)


def texto_error(error):
    """Deja solo el mensaje del servidor, sin el prefijo del driver ni el codigo de la llamada."""
    texto = str(error.args[-1]) if error.args else str(error)
    texto = re.sub(r"^.*\[SQL Server\]", "", texto)
    texto = re.sub(r"(\s*\(\d+\))*(\s*\(SQL\w+\))*\s*$", "", texto)
    return texto.strip()


class PantallaPaises(ttk.Frame):
    COLUMNAS = ("Id", "ISO", "Nombre", "Confederacion", "Huso horario", "PIB per capita", "Anio PIB")

    def __init__(self, padre, estado):
        super().__init__(padre, padding=10)
        self.estado = estado
        self.id_seleccionado = None
        self.campos = {}

        self.grilla = ttk.Treeview(self, columns=self.COLUMNAS, show="headings", height=12)
        anchos = (50, 60, 170, 110, 230, 110, 70)
        for columna, ancho in zip(self.COLUMNAS, anchos):
            self.grilla.heading(columna, text=columna)
            self.grilla.column(columna, width=ancho, anchor="w")
        self.grilla.grid(row=0, column=0, columnspan=4, sticky="nsew")
        self.grilla.bind("<<TreeviewSelect>>", self.al_seleccionar)
        barra = ttk.Scrollbar(self, orient="vertical", command=self.grilla.yview)
        self.grilla.configure(yscrollcommand=barra.set)
        barra.grid(row=0, column=4, sticky="ns")

        formulario = ttk.LabelFrame(self, text="Datos del pais", padding=10)
        formulario.grid(row=1, column=0, columnspan=5, sticky="ew", pady=(10, 0))
        etiquetas = (
            ("ISO", "Codigo ISO (3 letras)"),
            ("Nombre", "Nombre"),
            ("Confederacion", "Confederacion"),
            ("Huso", "Huso horario"),
            ("Pib", "PIB per capita (USD)"),
            ("Anio", "Anio del PIB"),
        )
        for i, (clave, titulo) in enumerate(etiquetas):
            fila, columna = divmod(i, 2)
            ttk.Label(formulario, text=titulo).grid(row=fila, column=columna * 2, sticky="w", padx=(0, 6), pady=3)
            if clave == "Confederacion":
                campo = ttk.Combobox(formulario, values=CONFEDERACIONES, state="readonly", width=28)
            elif clave == "Huso":
                campo = ttk.Combobox(formulario, values=self.husos_horarios(), state="readonly", width=28)
            else:
                campo = ttk.Entry(formulario, width=30)
            campo.grid(row=fila, column=columna * 2 + 1, sticky="w", padx=(0, 20), pady=3)
            self.campos[clave] = campo

        botones = ttk.Frame(self)
        botones.grid(row=2, column=0, columnspan=5, sticky="w", pady=(10, 0))
        ttk.Button(botones, text="Nuevo", command=self.nuevo).pack(side="left", padx=(0, 8))
        ttk.Button(botones, text="Guardar", command=self.guardar).pack(side="left", padx=(0, 8))
        ttk.Button(botones, text="Eliminar", command=self.eliminar).pack(side="left")

        self.columnconfigure(0, weight=1)
        self.rowconfigure(0, weight=1)
        self.cargar()

    def husos_horarios(self):
        with closing(conectar()) as conexion:
            return [fila[0] for fila in conexion.execute("SELECT name FROM sys.time_zone_info ORDER BY name")]

    def cargar(self):
        self.grilla.delete(*self.grilla.get_children())
        with closing(conectar()) as conexion:
            filas = conexion.execute(
                "SELECT IdPais, CodigoIso3, Nombre, Confederacion, HusoHorario, PibPerCapitaUsd, AnioPib "
                "FROM Torneo.Pais ORDER BY Nombre"
            ).fetchall()
        for fila in filas:
            self.grilla.insert("", "end", iid=str(fila[0]), values=["" if v is None else v for v in fila])

    def al_seleccionar(self, _evento):
        seleccion = self.grilla.selection()
        if not seleccion:
            return
        valores = self.grilla.item(seleccion[0], "values")
        self.id_seleccionado = int(valores[0])
        for clave, valor in zip(("ISO", "Nombre", "Confederacion", "Huso", "Pib", "Anio"), valores[1:]):
            self.escribir(clave, valor)

    def escribir(self, clave, valor):
        campo = self.campos[clave]
        if isinstance(campo, ttk.Combobox):
            campo.set(valor)
        else:
            campo.delete(0, "end")
            campo.insert(0, valor)

    def nuevo(self):
        self.id_seleccionado = None
        self.grilla.selection_remove(self.grilla.selection())
        for clave in self.campos:
            self.escribir(clave, "")

    def leer_formulario(self):
        """Devuelve los datos del formulario, o None si el PIB o el anio no son numeros."""
        pib = self.campos["Pib"].get().strip()
        anio = self.campos["Anio"].get().strip()
        try:
            pib = float(pib.replace(",", ".")) if pib else None
            anio = int(anio) if anio else None
        except ValueError:
            messagebox.showerror("Datos incorrectos", "El PIB y el anio deben ser numeros.")
            return None
        return (
            self.campos["ISO"].get().strip(),
            self.campos["Nombre"].get().strip(),
            self.campos["Confederacion"].get() or None,
            self.campos["Huso"].get() or None,
            pib,
            anio,
        )

    def guardar(self):
        datos = self.leer_formulario()
        if datos is None:
            return
        try:
            with closing(conectar()) as conexion:
                if self.id_seleccionado is None:
                    conexion.execute("EXEC Torneo.usp_Pais_Alta ?, ?, ?, ?, ?, ?", *datos)
                    self.estado.set("Pais agregado.")
                else:
                    conexion.execute("EXEC Torneo.usp_Pais_Modificacion ?, ?, ?, ?, ?, ?, ?", self.id_seleccionado, *datos)
                    self.estado.set("Pais modificado.")
        except pyodbc.Error as error:
            messagebox.showerror("No se pudo guardar", texto_error(error))
            return
        self.cargar()
        self.nuevo()

    def eliminar(self):
        if self.id_seleccionado is None:
            messagebox.showinfo("Eliminar", "Elija un pais de la lista.")
            return
        if not messagebox.askyesno("Eliminar", "Se va a eliminar el pais seleccionado. Continuar?"):
            return
        try:
            with closing(conectar()) as conexion:
                conexion.execute("EXEC Torneo.usp_Pais_Baja ?", self.id_seleccionado)
            self.estado.set("Pais eliminado.")
        except pyodbc.Error as error:
            messagebox.showerror("No se pudo eliminar", texto_error(error))
            return
        self.cargar()
        self.nuevo()


class PantallaImportacion(ttk.Frame):
    def __init__(self, padre, estado):
        super().__init__(padre, padding=10)
        self.estado = estado

        ttk.Label(self, text="Archivo CSV de arbitros (referees.csv)").grid(row=0, column=0, sticky="w")
        self.ruta = ttk.Entry(self, width=70)
        self.ruta.insert(0, ARCHIVO_ARBITROS)
        self.ruta.grid(row=1, column=0, sticky="ew", pady=4)
        ttk.Button(self, text="Elegir archivo...", command=self.elegir).grid(row=1, column=1, padx=(8, 0))
        ttk.Button(self, text="Importar arbitros", command=self.importar).grid(row=2, column=0, sticky="w", pady=(6, 10))
        ttk.Label(
            self,
            text="El archivo lo lee SQL Server: tiene que estar en una carpeta a la que acceda la cuenta del servicio.",
        ).grid(row=3, column=0, columnspan=2, sticky="w")

        self.resultado = tk.Text(self, height=18, width=100, state="disabled", font=("Consolas", 9))
        self.resultado.grid(row=4, column=0, columnspan=2, sticky="nsew", pady=(8, 0))
        self.columnconfigure(0, weight=1)
        self.rowconfigure(4, weight=1)

    def elegir(self):
        archivo = filedialog.askopenfilename(
            title="Elegir el archivo", filetypes=[("CSV", "*.csv"), ("Todos los archivos", "*.*")]
        )
        if archivo:
            self.ruta.delete(0, "end")
            self.ruta.insert(0, os.path.normpath(archivo))

    def mostrar(self, lineas):
        self.resultado.configure(state="normal")
        self.resultado.delete("1.0", "end")
        self.resultado.insert("1.0", "\n".join(lineas))
        self.resultado.configure(state="disabled")

    def importar(self):
        lineas, aviso = [], None
        try:
            with closing(conectar()) as conexion:
                cursor = conexion.cursor()
                cursor.execute("EXEC Importacion.usp_ImportarArbitrosCsv @NombreArchivo = ?", self.ruta.get().strip())
                # El SP devuelve el resumen y la lista de errores, y despues informa la importacion
                # parcial con un error: se leen los resultados antes de que llegue.
                try:
                    while True:
                        if cursor.description:
                            columnas = [c[0] for c in cursor.description]
                            lineas.append(" | ".join(columnas))
                            for fila in cursor.fetchall():
                                lineas.append(" | ".join(str(v) for v in fila))
                            lineas.append("")
                        if not cursor.nextset():
                            break
                except pyodbc.Error as error:
                    aviso = texto_error(error)
        except pyodbc.Error as error:
            messagebox.showerror("No se pudo importar", texto_error(error))
            return
        if aviso:
            lineas.append(aviso)
        self.mostrar(lineas)
        self.estado.set(aviso or "Importacion terminada.")


class PantallaReportes(ttk.Frame):
    def __init__(self, padre, estado):
        super().__init__(padre, padding=10)
        self.estado = estado

        ttk.Label(self, text="Reporte").grid(row=0, column=0, sticky="w")
        self.reporte = ttk.Combobox(self, values=list(REPORTES_XML), state="readonly", width=40)
        self.reporte.current(0)
        self.reporte.grid(row=1, column=0, sticky="w", pady=4)
        ttk.Button(self, text="Generar y guardar XML...", command=self.generar).grid(row=1, column=1, padx=(8, 0))

        self.vista = tk.Text(self, height=24, width=100, state="disabled", font=("Consolas", 9))
        self.vista.grid(row=2, column=0, columnspan=2, sticky="nsew", pady=(10, 0))
        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)

    def generar(self):
        procedimiento, nombre = REPORTES_XML[self.reporte.get()]
        try:
            with closing(conectar()) as conexion:
                xml = conexion.execute("EXEC " + procedimiento).fetchone()[0]
        except pyodbc.Error as error:
            messagebox.showerror("No se pudo generar el reporte", texto_error(error))
            return
        if not xml:
            messagebox.showinfo("Reporte", "El reporte no devolvio datos.")
            return
        destino = filedialog.asksaveasfilename(
            title="Guardar el XML", initialfile=nombre, defaultextension=".xml", filetypes=[("XML", "*.xml")]
        )
        if destino:
            with open(destino, "w", encoding="utf-8") as archivo:
                archivo.write('<?xml version="1.0" encoding="utf-8"?>\n' + xml)
            self.estado.set("XML guardado en " + destino)
        self.vista.configure(state="normal")
        self.vista.delete("1.0", "end")
        self.vista.insert("1.0", xml[:6000] + ("\n..." if len(xml) > 6000 else ""))
        self.vista.configure(state="disabled")


class Aplicacion(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Mundial de Futbol - Gestion")
        self.geometry("960x640")
        self.estado = tk.StringVar(value="Conectado a %s, base %s." % (SERVIDOR, BASE))

        pestanas = ttk.Notebook(self)
        pestanas.pack(fill="both", expand=True, padx=8, pady=8)
        pestanas.add(PantallaPaises(pestanas, self.estado), text="Paises")
        pestanas.add(PantallaImportacion(pestanas, self.estado), text="Importacion")
        pestanas.add(PantallaReportes(pestanas, self.estado), text="Reportes XML")
        ttk.Label(self, textvariable=self.estado, relief="sunken", anchor="w").pack(fill="x", side="bottom")


if __name__ == "__main__":
    try:
        Aplicacion().mainloop()
    except pyodbc.Error as error_conexion:
        messagebox.showerror("Sin conexion", texto_error(error_conexion))
