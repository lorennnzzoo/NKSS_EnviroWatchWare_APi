using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface ILicenseService
    {
        bool IsLicenseValid(string licenseType);
        Models.Licenses.LicenseResponse GetLicenseResponseByType(string licenseType);
        Models.Licenses.License GetLicenseByType(string licenseType);
        void AddLicense(Models.Licenses.License license);
        void DeleteLicenes(string licenseType);
        void Update(Models.Licenses.License license);

        void GenerateLicenseSoftrack(Models.Licenses.Registration registration);
        string GetCompanyNameSoftrack(int id);
    }
}
