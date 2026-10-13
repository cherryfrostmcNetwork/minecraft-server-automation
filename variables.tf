# =============================================================================
# variables.tf  —  Entradas configurables del despliegue
# =============================================================================
# NOTA DE APRENDIZAJE (IaC):
#   Las variables separan la CONFIGURACIÓN de la LÓGICA. Así cambiás región,
#   tamaño de instancia o versión sin tocar los recursos. Los valores reales
#   van en terraform.tfvars (o -var en la CLI), nunca hardcodeados.
# =============================================================================

# ----------------------------- AWS / Provider --------------------------------

variable "aws_region" {
  description = "Región de AWS donde se despliega el servidor."
  type        = string
  default     = "us-east-1" # Confirmado por el usuario.
}

variable "aws_profile" {
  description = "Perfil de credenciales en ~/.aws/credentials o ~/.aws/config."
  type        = string
  default     = "default" # Confirmado por el usuario.
}

# ----------------------------- Instancia EC2 ---------------------------------

variable "instance_type" {
  description = "Tipo de instancia EC2. Objetivo ~2GB RAM."
  type        = string
  # t3.small = 2 vCPU / 2GB RAM. Candidato razonable para 2GB + swap.
  # TODO [INSTANCIA]: confirmar tipo. Alternativas: t4g.small (ARM, más barato,
  #   requiere AMI ARM y Java ARM) o t3.medium (4GB, sin tanta dependencia de swap).
  default = "t3.small"
}

variable "key_name" {
  description = "Nombre del key pair EC2 para acceso SSH."
  type        = string
  default     = "master" # key pair creada vía AWS CLI, reutilizable en otros proyectos.
}

variable "allowed_ssh_cidr" {
  description = "CIDR autorizado a conectarse por SSH (puerto 22)."
  type        = string
  # ADVERTENCIA DE SEGURIDAD: 0.0.0.0/0 expone SSH a toda internet.
  #   El usuario confirmó que entiende el riesgo y lo deja abierto a propósito.
  default = "0.0.0.0/0"
}

# ----------------------------- Minecraft / Fabric ----------------------------

variable "mc_version" {
  description = "Versión de Minecraft."
  type        = string
  default     = "1.21.1" # Confirmado por el usuario.
}

variable "fabric_loader_version" {
  description = "Versión del Fabric Loader."
  type        = string
  # Confirmado desde modrinth.index.json del modpack: "fabric-loader": "0.19.5".
  default = "0.19.5"
}

variable "mc_ram_mb" {
  description = "RAM (MB) asignada a la JVM del servidor Minecraft."
  type        = number
  # En una instancia de 2GB, dejar margen para el SO. 1536MB es un punto de
  # partida; el swap cubre picos durante la construcción inicial del mundo.
  default = 1536
}

# ----------------------------- Swap ------------------------------------------

variable "swap_size_gb" {
  description = "Tamaño del archivo de swap (GB) para la construcción inicial."
  type        = number
  default     = 4 # Colchón para la carga de mods/generación de chunks en 2GB.
}

# ----------------------------- Modpack (Modrinth) ----------------------------

# TODO [MODPACK]: estructura real del archivo pendiente de confirmación.
#   El usuario tiene un modpack de Modrinth en ~/Downloads ("zip sobre zip").
#   Formato probable: .mrpack (ZIP con modrinth.index.json + overrides/),
#   que referencia los mods por URL — NO los incluye como .jar.
#   Hasta ver `unzip -l`, el mecanismo de aprovisionamiento queda sin definir.
variable "modpack_source" {
  description = "Origen del modpack. Pendiente de definir (ver TODO MODPACK)."
  type        = string
  default     = ""
}

# ----------------------------- Modpacks de descarga (cliente) ----------------
# Rutas locales a los 3 formatos de modpack que se suben al bucket público.

variable "pack_mrpack_path" {
  description = "Ruta local al modpack .mrpack (Modrinth)."
  type        = string
  default     = "/Users/riosisraelg/Downloads/Soxdxdxdd.mrpack"
}

variable "pack_zip_path" {
  description = "Ruta local al modpack .zip completo."
  type        = string
  default     = "/Users/riosisraelg/Downloads/Soxdxdxdd.zip"
}

variable "pack_curseforge_path" {
  description = "Ruta local al modpack .zip de CurseForge."
  type        = string
  default     = "/Users/riosisraelg/Downloads/SoxdxdxddCurseforge.zip"
}
