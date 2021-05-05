
package acceptance_tests

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"time"

	scp "github.com/bramvdbogaerde/go-scp"
	"golang.org/x/crypto/ssh"
)

// runs command on remote machine
func runOnRemote(user string, addr string, privateKey string, cmd string) (string, string, error) {
	client, err := buildSSHClient(user, addr, privateKey)
	if err != nil {
		return "", "", err
	}

	session, err := client.NewSession()
	if err != nil {
		return "", "", err
	}
	defer session.Close()

	var stdOutBuffer bytes.Buffer
	var stdErrBuffer bytes.Buffer
	session.Stdout = &stdOutBuffer
	session.Stderr = &stdErrBuffer
	err = session.Run(cmd)
	return stdOutBuffer.String(), stdErrBuffer.String(), err
}

func copyFileToRemote(user string, addr string, privateKey string, remotePath string, fileReader io.Reader, permissions string) error {
	clientConfig, err := buildSSHClientConfig(user, addr, privateKey)
	if err != nil {
		return err
	}

	scpClient := scp.NewClient(fmt.Sprintf("%s:22", addr), clientConfig)
	if err := scpClient.Connect(); err != nil {
		return err
	}

	return scpClient.CopyFile(context.Background(), fileReader, remotePath, permissions)
}

// Forwards a TCP connection from a given port on the local machine to a given port on the remote machine
// Starts in backgound, cancel via context
func startSSHPortForwarder(user string, addr string, privateKey string, localPort, remotePort int, ctx context.Context) error {
	remoteConn, err := buildSSHClient(user, addr, privateKey)
	if err != nil {
		return err
	}

	writeLog(fmt.Sprintf("Listening on 127.0.0.1:%d on local machine\n", remotePort))
	localListener, err := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", localPort))
	if err != nil {
		return err
	}

	go func() {
		for {
			localClient, err := localListener.Accept()
			if err != nil {
				if err == io.EOF {
					writeLog("Local connection closed")
				} else {
					writeLog(fmt.Sprintf("Error accepting connection on local listener: %s\n", err.Error()))
				}

				return
			}

			remoteConn, err := remoteConn.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", remotePort))
			if err != nil {
				writeLog(fmt.Sprintf("Error dialing local port %d: %s\n", remotePort, err.Error()))
				return
			}

			// From https://sosedoff.com/2015/05/25/ssh-port-forwarding-with-go.html
			copyConnections(localClient, remoteConn)
		}
	}()

	go func() {
		<-ctx.Done()
		writeLog("Closing local listener")
		localListener.Close()
	}()

	return nil
}

// Forwards a TCP connection from a given port on the remote machine to a given port on the local machine
// Starts in backgound, cancel via context
func startReverseSSHPortForwarder(user string, addr string, privateKey string, remotePort, localPort int, ctx context.Context) error {
	remoteConn, err := buildSSHClient(user, addr, privateKey)
	if err != nil {
		return err
	}

	writeLog(fmt.Sprintf("Listening on 127.0.0.1:%d on remote machine\n", remotePort))
	remoteListener, err := remoteConn.Listen("tcp", fmt.Sprintf("127.0.0.1:%d", remotePort))
	if err != nil {
		return err
	}

	go func() {
		for {
			remoteClient, err := remoteListener.Accept()
			if err != nil {
				if err == io.EOF {
					writeLog("Remote connection closed")
				} else {
					writeLog(fmt.Sprintf("Error accepting connection on remote listener: %s\n", err.Error()))
				}

				return
			}

			localConn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", localPort))
			if err != nil {
				writeLog(fmt.Sprintf("Error dialing local port %d: %s\n", localPort, err.Error()))
				return
			}