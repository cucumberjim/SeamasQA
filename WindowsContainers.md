Yes, you can run a full Windows container on a Windows Server Core host (https://www.google.com/search?q=Windows+Server+Core+host).
Microsoft explicitly supports running the heavier full microsoft/windows base image (or the microsoft/windows-server base image) on a lighter Windows Server Core host operating system. This is a very common architecture for automated testing, continuous integration (CI) workflows, and configuration management scripts (like Ansible, Chef, or PowerShell DSC) that require heavy system APIs or dependencies missing from Server Core. [1] (/goto?url=CAESYgHrOzAVefSqTg5VAUq-eDVFwssEYJdo5KZURk6YnP0-fMUvVvtRhBiQs2Q2Sp9ZNJuG3m8IZWgq6f-O8P6ay6A6mkm810hh6l4qRMtyfY4bd0ZY0W1007iT5e5W8c8Mp2Ix), [2] (/goto?url=CAESogEB6zswFdwgUj1qIWK8d_o2o9lQcIQumg1tAuWnJgMPqoeAlhweSfC4ibjFNmUloHn5XvfjxTv-ppmZAn2Mqn_Hmqmao5UmHph4Zw7BOKRmBjGPOvPJVEl9wbNLTButy2KIIhS9ysWQY-IpX0t2eoTUsR3KF_K4o6hOy891-9YrLcvwg2ncLHayyfnR-jdlynkJFO-MNjC9MyRFZrx8iXYXwK0), [3] (/goto?url=CAESgwEB6zswFdauhjvEuyEXzKRsXotP8QMqZgEbKGV7jY6zk8V4dYnh46ghqpQ-bvkJ1wd3QVaYtdSCfirsjo-poYFotrPKcMO1ZHP3Z86WkbVaNBFp7pZb99b-61OTIjAkOF4Eq_nOhV5ZNtBmt7m_K_cK7xalyuULsZj8jV5wBLYykBlLPQ)
However, because Windows container architecture differs significantly from Linux, there are critical rules and limitations you must follow:

1. Match the OS Build Versions (or use Hyper-V Isolation)

The host operating system kernel and the container base image version must strictly align. [1] (/goto?url=CAESbQHrOzAVlRI00ZU4osoPBHfxzoz3J3NzWxYuNvkydH6eCWxmzvW_Tv_HYn8L3nTgICwzeHw60rlJklebm3QRE5MYI8VJf2JTMNgC7NkH-Qeyg3ChbcV1BZchnT1UVlq6aEIKl5-L5Lkdb0sXvNk)
• Process Isolation (High Performance): If your host is running Windows Server 2022 Core, your container image must also use a Windows Server 2022 full image tag (e.g., ://microsoft.com.*). [1] (/goto?url=CAESogEB6zswFZvBKC-XbnbzEU8Z1-8uSoPprF-5CRka3B6BdfS5fJUNlEj5oMWPwLL8KIPA5DUPyJdX_IS2EAPqHOrwKX1v3WzfsAFFajOmI3K3E3-JQ1aIVzlJ3s_vnktbJqCHu6JAqIFXDefXXftpCrUbxTpAPudvmT5QOyy_sBMWa7XxpQmF_ut_ZIwQeGuPNurhboV0vceprKSln5-vrPpKX4U), [2] (/goto?url=CAEShAEB6zswFf5_CLxayRX4SxmVGSuMDHHB8InGmrLD5y152XUx1o7lyHu-PtyuAms6UMNk79Xv-dS_36rVzdj0VOLIUXycG-J4FReKmq8hvNwkQp-0GUUliy8R0ETJAeqi0gyFmV5HPXz8Q74w35slFMm9iLoC51m2k8wGARL4TF-xgDxBmQw)
• Hyper-V Isolation (Fallback): If you are running mismatched versions (e.g., testing a Windows 10/11 or Windows Server 2019 full image on a Server 2022 Core host), you must explicitly run the container using --isolation=hyperv. This boots an ultralight VM kernel underneath, which adds slightly more resource overhead but ensures compatibility. [1] (/goto?url=CAESogEB6zswFZvBKC-XbnbzEU8Z1-8uSoPprF-5CRka3B6BdfS5fJUNlEj5oMWPwLL8KIPA5DUPyJdX_IS2EAPqHOrwKX1v3WzfsAFFajOmI3K3E3-JQ1aIVzlJ3s_vnktbJqCHu6JAqIFXDefXXftpCrUbxTpAPudvmT5QOyy_sBMWa7XxpQmF_ut_ZIwQeGuPNurhboV0vceprKSln5-vrPpKX4U), [2] (/goto?url=CAESbQHrOzAVlRI00ZU4osoPBHfxzoz3J3NzWxYuNvkydH6eCWxmzvW_Tv_HYn8L3nTgICwzeHw60rlJklebm3QRE5MYI8VJf2JTMNgC7NkH-Qeyg3ChbcV1BZchnT1UVlq6aEIKl5-L5Lkdb0sXvNk), [3] (/goto?url=CAEShAEB6zswFf5_CLxayRX4SxmVGSuMDHHB8InGmrLD5y152XUx1o7lyHu-PtyuAms6UMNk79Xv-dS_36rVzdj0VOLIUXycG-J4FReKmq8hvNwkQp-0GUUliy8R0ETJAeqi0gyFmV5HPXz8Q74w35slFMm9iLoC51m2k8wGARL4TF-xgDxBmQw)

2. Expect Large Image Sizes

The full Windows container image contains a significantly expanded API surface compared to Server Core. [1] (/goto?url=CAESogEB6zswFdwgUj1qIWK8d_o2o9lQcIQumg1tAuWnJgMPqoeAlhweSfC4ibjFNmUloHn5XvfjxTv-ppmZAn2Mqn_Hmqmao5UmHph4Zw7BOKRmBjGPOvPJVEl9wbNLTButy2KIIhS9ysWQY-IpX0t2eoTUsR3KF_K4o6hOy891-9YrLcvwg2ncLHayyfnR-jdlynkJFO-MNjC9MyRFZrx8iXYXwK0)
• A full microsoft/windows image download is massive (often exceeding 10GB to 15GB uncompressed).
• For automated testing pipelines, ensure your container host storage has ample drive space to cache these images. [1] (/goto?url=CAESgwEB6zswFdauhjvEuyEXzKRsXotP8QMqZgEbKGV7jY6zk8V4dYnh46ghqpQ-bvkJ1wd3QVaYtdSCfirsjo-poYFotrPKcMO1ZHP3Z86WkbVaNBFp7pZb99b-61OTIjAkOF4Eq_nOhV5ZNtBmt7m_K_cK7xalyuULsZj8jV5wBLYykBlLPQ)

3. There is No Graphical Desktop Interface (GUI)

Even though it is called a "Full Windows" container, it remains headless. [1] (/goto?url=CAESjQEB6zswFZJrnw_3h6Yw3v-f_QtgjUhxbnDPZcPUXvAb1H-uvgISXyVHruDuAIeaMSZ5wksDfjz_DiBrbIUhM5vt45cK2OiKzRry8TqnvBSqgf_RVehU-KzAYAANhfHVHhYi49_9VtVE292CLEgKK0gnsSUnqhzJ4FywDNzUQFZTeiF75dpnKWywg9xAXNc)
• You cannot launch a graphical desktop, and you cannot RDP directly into the container UI.
• For automated testing, all applications, installers, and testing tools (like Selenium, Appium, or test runners) must be driven completely headlessly via command line, PowerShell, or automated scripts. [1] (/goto?url=CAESgwEB6zswFdauhjvEuyEXzKRsXotP8QMqZgEbKGV7jY6zk8V4dYnh46ghqpQ-bvkJ1wd3QVaYtdSCfirsjo-poYFotrPKcMO1ZHP3Z86WkbVaNBFp7pZb99b-61OTIjAkOF4Eq_nOhV5ZNtBmt7m_K_cK7xalyuULsZj8jV5wBLYykBlLPQ), [2] (/goto?url=CAESjQEB6zswFZJrnw_3h6Yw3v-f_QtgjUhxbnDPZcPUXvAb1H-uvgISXyVHruDuAIeaMSZ5wksDfjz_DiBrbIUhM5vt45cK2OiKzRry8TqnvBSqgf_RVehU-KzAYAANhfHVHhYi49_9VtVE292CLEgKK0gnsSUnqhzJ4FywDNzUQFZTeiF75dpnKWywg9xAXNc)

Example Deployment Command

To test application configurations or run automated testing scripts inside a full Windows container on your Core host, you would invoke a command resembling this:
powershell
# For matched host/container versions using high-performance process isolation
docker run --rm -it mcr.microsoft.com/windows:ltsc2019 powershell

# If running mismatched versions, enforce Hyper-V isolation
docker run --isolation=hyperv --rm -it mcr.microsoft.com/windows:ltsc2019 powershell
Use code with caution.
If you want to fine-tune your testing pipeline, tell me:
• What specific automation or configuration tool are you trying to test? (e.g., Ansible, Puppet, UI-testing frameworks like Selenium)
• What version of Windows Server Core is your host running?
I can provide the exact Dockerfile structure and isolation flags needed to get your pipeline running.

