using Models;
using Post = Models.Post;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface ICompanyService
    {
        IEnumerable<Company> GetAllCompanies();
        Company GetCompanyById(int id);
        void CreateCompany(Post.Company company);
        void UpdateCompany(Models.Put.Company company);
        void DeleteCompany(int id);
    }
}
