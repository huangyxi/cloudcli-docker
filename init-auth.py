#!/usr/bin/env python3

import sqlite3
import argparse
import os

def main():
	parser = argparse.ArgumentParser(
		description="Initialize the cloudcli authentication database by inserting a default user if the users table is empty."
	)

	default_db_path = os.path.expanduser("~/.cloudcli/auth.db")

	parser.add_argument(
		"db_path",
		nargs="?",
		default=default_db_path,
		help=f"Path to the CloudCLI Authentication SQLite database file (default: {default_db_path})"
	)

	args = parser.parse_args()

	if not os.path.exists(args.db_path):
		print(f"Error: Database file not found at {args.db_path}. Please run `cloudcli` first to initialize the database.")
		exit(1)

	conn = sqlite3.connect(args.db_path)

	conn.execute("""
		INSERT INTO users (
			username,
			password_hash,
			created_at,
			last_login,
			is_active,
			git_name,
			git_email,
			has_completed_onboarding
		)
		SELECT
			'default',
			'',
			datetime('now'),
			datetime('now'),
			1,
			'',
			'',
			0
		WHERE NOT EXISTS (
			SELECT 1 FROM users
		);
	""")

	conn.commit()
	conn.close()

if __name__ == "__main__":
	main()
