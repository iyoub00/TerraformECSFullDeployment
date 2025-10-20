python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
touch .env
set -a; source .env; set +a;
python app.py