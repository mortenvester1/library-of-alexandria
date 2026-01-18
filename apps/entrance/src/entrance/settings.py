from typing import Set

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings and configuration.

    Attributes:
        log_level: Logging level
        config_file: Path to the YAML configuration file
        blocked_ports: Set of ports that are blocked for security reasons
        allowed_origins: List of allowed CORS origins
        allow_localhost_any_port: Allow any port on localhost/127.0.0.1
        allow_private_network: Allow private network ranges
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        env_prefix="ENTRANCE_",
        extra="ignore",
    )

    # Application settings
    log_level: str = "INFO"
    config_file: str = "config.yaml"

    # Security settings
    blocked_ports: Set[int] = {
        # Well-known system ports (0-1023) - require root/admin privileges
        # FTP
        20,
        21,
        # SSH
        22,
        # Telnet
        23,
        # SMTP
        25,
        # DNS
        53,
        # HTTP
        80,
        # Kerberos
        88,
        # POP3
        110,
        # NNTP
        119,
        # NTP
        123,
        # NetBIOS
        137,
        138,
        139,
        # IMAP
        143,
        # SNMP
        161,
        162,
        # LDAP
        389,
        # HTTPS
        443,
        # SMB
        445,
        # SMTPS
        465,
        # Syslog
        514,
        # LDAPS
        636,
        # IMAPS
        993,
        # POP3S
        995,
        # Commonly exploited database ports
        1433,  # MS SQL Server
        1521,  # Oracle
        3306,  # MySQL
        5432,  # PostgreSQL
        27017,  # MongoDB
        # Redis
        6379,
        # Elasticsearch
        9200,
        9300,
    }

    # CORS settings
    allowed_origins: list[str] = [
        "http://localhost",
        "http://127.0.0.1",
    ]

    # Allow any port on localhost/127.0.0.1
    allow_localhost_any_port: bool = True

    # Allow private network ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
    allow_private_network: bool = True

    def is_port_blocked(self, port: int) -> bool:
        """Check if a port is blocked.

        Args:
            port: Port number to check

        Returns:
            True if port is blocked, False otherwise
        """
        return port in self.blocked_ports

    def get_cors_origin_regex(self) -> str:
        """Get CORS origin regex pattern.

        Returns:
            Regex pattern for allowed CORS origins
        """
        if self.allow_private_network:
            # Allow localhost and private network ranges
            return (
                r"http://(localhost|127\.0\.0\.1|"
                r"192\.168\.\d{1,3}\.\d{1,3}|"
                r"10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
                r"172\.(1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3})"
                r"(:\d+)?"
            )
        else:
            # Only allow localhost
            return r"http://(localhost|127\.0\.0\.1)(:\d+)?"


# Global settings instance
settings = Settings()
