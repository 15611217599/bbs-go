package server

import (
	"bbs-go/internal/install"
	"bbs-go/internal/pkg/config"
	"fmt"
	"log/slog"

	_ "github.com/golang-migrate/migrate/v4/source/file"
)

func Init() {
	install.InitConfig()
	install.InitLogger()
	
	slog.Info("Initializing locales...")
	if err := install.InitLocales(); err != nil {
		panic(fmt.Errorf("failed to init locales: %w", err))
	}
	slog.Info("Locales initialized successfully")
	
	if config.Instance.Installed {
		slog.Info("System already installed, initializing database...")
		if err := install.InitDB(); err != nil {
			panic(fmt.Errorf("failed to init database: %w", err))
		}
		slog.Info("Database initialized successfully")
		
		if err := install.InitOthers(); err != nil {
			panic(fmt.Errorf("failed to init others: %w", err))
		}
		slog.Info("Other components initialized successfully")
	} else {
		slog.Info("System not installed yet, skipping database initialization")
	}
	
	slog.Info("Server initialization completed")
}
