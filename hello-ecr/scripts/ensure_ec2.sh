  deploy:
    needs: [build, ensure_ec2]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with: { name: hello-ecr-artifact, path: ./artifact }
      - name: Verify artifact
        run: cd artifact && sha256sum -c hello-ecr.tgz.sha256
      - uses: actions/download-artifact@v4
        with: { name: ephemeral-key, path: ./ssh }
      - name: SSH bootstrap
        run: |
          chmod 600 ./ssh/key.pem
          mkdir -p ~/.ssh && touch ~/.ssh/known_hosts
          ssh-keyscan -H ${{ needs.ensure_ec2.outputs.PUBLIC_IP }} >> ~/.ssh/known_hosts
          # wait for ssh
          for i in {1..30}; do
            nc -z ${{ needs.ensure_ec2.outputs.PUBLIC_IP }} 22 && break || (echo "waiting for ssh..." && sleep 5)
          done
      - name: Upload & deploy
        env:
          HOST: ${{ needs.ensure_ec2.outputs.PUBLIC_IP }}
          PORT: ${{ env.APP_PORT }}
        run: |
          scp -i ./ssh/key.pem ./artifact/hello-ecr.tgz ubuntu@$HOST:/home/ubuntu/hello-ecr.tgz
          scp -i ./ssh/key.pem hello-ecr/scripts/deploy_systemd.sh ubuntu@$HOST:/home/ubuntu/deploy_systemd.sh
          ssh -i ./ssh/key.pem ubuntu@$HOST "bash /home/ubuntu/deploy_systemd.sh"
