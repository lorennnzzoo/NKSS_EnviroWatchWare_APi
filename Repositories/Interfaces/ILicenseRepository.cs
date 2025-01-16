using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Repositories.Interfaces
{
    public interface ILicenseRepository
    {
        Models.Licenses.License GetLicenseByType(string licenseType);
        void Add(Models.Licenses.License license);
        void Update(Models.Licenses.License license);
        void Delete(string licenseType);
    }
}
