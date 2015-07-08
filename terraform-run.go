package main

import (
  "fmt"
  "io"
  "os"
  "os/exec"
  "syscall"
)

func CopyDir(source string, dest string) (err error) {
  // Get properties of source directory
  sourceInfo, err := os.Stat(source)
  if err != nil {
    return err
  }

  // Create destination directory
  err = os.MkdirAll(dest, sourceInfo.Mode())
  if err != nil {
    return err
  }

  sourceDirectory, _ := os.Open(source)
  objects, err := sourceDirectory.Readdir(-1)
  for _, obj := range objects {
    sourceFilePointer := source + "/" + obj.Name()
    destinationFilePointer := dest + "/" + obj.Name()

    if obj.IsDir() {
      // Recursively copy sub-directories.
      err = CopyDir(sourceFilePointer, destinationFilePointer)
      if err != nil {
        fmt.Println(err)
      }
    } else {
      // Perform copy
      err = CopyFile(sourceFilePointer, destinationFilePointer)
      if err != nil {
        fmt.Println(err)
      }
    }
  }

  return
}

func CopyFile(source string, dest string) (err error) {
  sourceFile, err := os.Open(source)
  if err != nil {
    return err
  }

  defer sourceFile.Close()

  destFile, err := os.Create(dest)
  if err != nil {
    return err
  }

  defer destFile.Close()

  _, err = io.Copy(destFile, sourceFile)
  if err == nil {
    sourceInfo, err := os.Stat(source)
    if err != nil {
      err = os.Chmod(dest, sourceInfo.Mode())
    }
  }

  return
}

func ExecuteTerraform(dir string) (err error) {
  err = os.Chdir(dir)
  if err != nil {
    return err
  }

  // Append domain variable to terraform.tfvars
  f, err := os.OpenFile("terraform.tfvars", os.O_APPEND|os.O_WRONLY, 0600)
  if err != nil {
    return err
  }

  defer f.Close()

  domain := fmt.Sprintf("domain = \"%s\"", "suitecrmtest.cloudservices.marketing")
  if _, err = f.WriteString(domain); err != nil {
    return err
  }

  terraformBinary, lookErr := exec.LookPath("terraform")
  if lookErr != nil {
    return lookErr
  }
  args := []string{"terraform", "apply"}
  env := os.Environ()
  execErr := syscall.Exec(terraformBinary, args, env)
  if execErr != nil {
    return execErr
  }

  return
}

func main() {
  sourceDir := "suitecrm-do-base"
  destDir := "suitecrm-do-test"

  // Check if source directory exists
  src, err := os.Stat(sourceDir)
  if err != nil {
    panic(err)
  }

  if ! src.IsDir() {
    fmt.Println("Source is not a directory.")
    os.Exit(1)
  }

  // Check if destination directory exists
  _, err = os.Open(destDir)
  if ! os.IsNotExist(err) {
    fmt.Println("Destination directory already exists. Abort!")
    os.Exit(1)
  }

  err = CopyDir(sourceDir, destDir)
  if err != nil {
    fmt.Println(err)
  } else {
    fmt.Println("Directory copied")
  }

  err = ExecuteTerraform(destDir)
  if err != nil {
    panic(err)
  } else {
    fmt.Println("Terraform configuration applied")
  }
}
